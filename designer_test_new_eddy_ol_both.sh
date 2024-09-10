#!/bin/bash
#SBATCH --mail-user=rf2485@nyulangone.org
#SBATCH --mail-type=ALL
#SBATCH	--gres=gpu:1 -p radiology,gpu4_short,gpu4_medium,gpu4_long,gpu8_short,gpu8_medium,gpu8_long
#SBATCH --time=12:00:00
#SBATCH --mem=32G

basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/designer_tbss/

subj_list=$(cut -f1 -d$'\t' $projectdir/dwi_over_55.tsv)
subj_list=($subj_list)
subj_num=1
j=${subj_list[$subj_num]}

rawdwi=$basedir/raw/$j/dwi/${j}_dwi
rawT1=$basedir/raw/$j/anat/${j}_T1w
designerdir=$projectdir/designer_new_eddy_ol_both/$j/
intdir=$designerdir/intermediate_nifti/
mkdir -p $intdir
synb0in=$designerdir/synb0/INPUTS/
mkdir -p $synb0in
synb0out=$designerdir/synb0/OUTPUTS/
mkdir -p $synb0out

module load singularity/3.9.8
module load cuda/11.8
module load miniconda3/gpu/4.9.2
# conda create -c https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/public/ -c conda-forge -n fsl_eddy fsl-eddy-cuda-10.2==2401.2 fsl-bet2==2111.8 fsl-avwutils==2209.2
source activate ~/.conda/envs/fsl_eddy/
export FSLDIR=$CONDA_PREFIX
source $FSLDIR/etc/fslconf/fsl.sh

#concatenate and convert raw dwi
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $rawdwi.json -fslgrad $rawdwi.bvec $rawdwi.bval $rawdwi.nii.gz $designerdir/working.mif -force
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert $designerdir/working.mif -json_export $designerdir/dwi_raw.json -export_grad_fsl $designerdir/dwi_raw.bvec $designerdir/dwi_raw.bval $designerdir/dwi_raw.nii -force

#denoise, degibbs, and normalize with designer
singularity exec --nv --bind $basedir $basedir/designer2_latest.sif designer -denoise -shrinkage frob -adaptive_patch -degibbs -normalize -nocleanup -scratch $designerdir/tmp $designerdir/dwi_raw.nii $intdir/2_dwi_degibbs.nii

#move denoised files and calculate residual
mv $designerdir/tmp/sigma.nii $designerdir/noisemap.nii
mv $designerdir/tmp/tmp_dwidn.nii $intdir/1_dwi_denoised.nii
cp $designerdir/dwi_raw.json $intdir/1_dwi_denoised.json
cp $designerdir/dwi_raw.bvec $intdir/1_dwi_denoised.bvec
cp $designerdir/dwi_raw.bval $intdir/1_dwi_denoised.bval
singularity exec --bind $basedir $basedir/neurodock_latest.sif mrcalc $designerdir/dwi_raw.nii $designerdir/intermediate_nifti/1_dwi_denoised.nii -sub $designerdir/residual.nii

#move and convert degibbs/normalized files
cp $designerdir/dwi_raw.json $intdir/2_dwi_degibbs.json
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $intdir/2_dwi_degibbs.json -fslgrad $intdir/2_dwi_degibbs.bvec $intdir/2_dwi_degibbs.bval $intdir/2_dwi_degibbs.nii $designerdir/working.mif -force

#prepare for synb0
##create b0 and acqparams
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif dwiextract -bzero $designerdir/working.mif - | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert - -coord 3 0 -axes 0,1,2 $intdir/b0_1_working.mif -force
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -export_pe_table $synb0in/acqparams.txt $intdir/b0_1_working.mif $synb0in/b0.nii.gz -force
rm $intdir/b0_1_working.mif
echo " 0 1 0 0.000" >> $synb0in/acqparams.txt
##copy T1
cp $rawT1.nii.gz $synb0in/T1.nii.gz

#synb0
singularity run -e -B $synb0in:/INPUTS -B $synb0out:/OUTPUTS -B $basedir/license.txt:/extra/freesurfer/license.txt $basedir/synb0-disco_v3.1.sif
##copy and convert synb0 output
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -import_pe_table $synb0in/acqparams.txt $synb0out/b0_all.nii.gz $synb0out/b0_all.mif -force
cp $synb0out/b0_all.mif $designerdir/tmp/se_epi.mif

cd $designerdir/tmp
#prepare for topup
##copy and convert working.mif
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert $designerdir/working.mif dwi.mif -json_export dwi.json -force
##replace first b0 of se_epi with first b0 of dwi
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi.mif dwi_first_bzero.mif -coord 3 0 -axes 0,1,2
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert se_epi.mif - -coord 3 1 | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrcat dwi_first_bzero.mif - se_epi_firstdwibzero.mif -axis 3
##create files for topup input
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert se_epi_firstdwibzero.mif topup_in.nii -strides -1,+2,+3,+4 -export_pe_table topup_datain.txt

#topup
topup --imain=topup_in.nii --datain=topup_datain.txt --out=field --fout=field_map.nii.gz --config=${FSLDIR}/etc/flirtsch/b02b0.cnf --verbose

#prepare for eddy
##create eddy mask
bet $synb0in/b0.nii.gz eddy -m -n -R
rm eddy.nii.gz
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert eddy_mask.nii.gz - -strides -1,+2,+3 | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif maskfilter - dilate - | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert - eddy_mask.nii -datatype float32 -strides -1,+2,+3
rm eddy_mask.nii.gz	
##create files for eddy input
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi.mif eddy_in.nii -strides -1,+2,+3,+4 -export_grad_fsl bvecs bvals -export_pe_eddy eddy_config.txt eddy_indices.txt

#eddy
eddy_cuda10.2 --imain=eddy_in.nii --mask=eddy_mask.nii --acqp=eddy_config.txt --index=eddy_indices.txt --bvecs=bvecs --bvals=bvals --topup=field --data_is_shelled --slm=linear --niter=8 --fwhm=10,6,4,2,0,0,0,0 --repol --ol_type=both --cnr_maps --verbose --json=dwi.json --out=dwi_post_eddy

#move and convert eddy output
intermediate=$designerdir/intermediate_nifti/2_dwi_undistorted
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi_post_eddy.nii.gz $intermediate.mif -strides -1,2,3,4 -fslgrad dwi_post_eddy.eddy_rotated_bvecs bvals
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -export_grad_fsl $intermediate.bvec $intermediate.bval -json_export $intermediate.json $intermediate.mif $intermediate.nii -force
mv $intermediate.mif $designerdir/working.mif

qc_eddy=$designerdir/metrics_qc/eddy
mkdir -p $qc_eddy
cp dwi_post_eddy.eddy_parameters $qc_eddy/eddy_parameters
cp dwi_post_eddy.eddy_movement_rms $qc_eddy/eddy_movement_rms
cp dwi_post_eddy.eddy_restricted_movement_rms $qc_eddy/eddy_restricted_movement_rms
cp dwi_post_eddy.eddy_post_eddy_shell_alignment_parameters $qc_eddy/eddy_post_eddy_shell_alignment_parameters
cp dwi_post_eddy.eddy_post_eddy_shell_PE_translation_parameters $qc_eddy/eddy_post_eddy_shell_PE_translation_parameters
cp dwi_post_eddy.eddy_outlier_report $qc_eddy/eddy_outlier_report
cp dwi_post_eddy.eddy_outlier_map $qc_eddy/eddy_outlier_map
cp dwi_post_eddy.eddy_outlier_n_stdev_map $qc_eddy/eddy_outlier_n_stdev_map
cp dwi_post_eddy.eddy_outlier_n_sqr_stdev_map $qc_eddy/eddy_outlier_n_sqr_stdev_map
cp dwi_post_eddy.eddy_outlier_free_data.nii.gz $qc_eddy/eddy_outlier_free_data.nii.gz
cp dwi_post_eddy.eddy_movement_over_time $qc_eddy/eddy_movement_over_time
cp dwi_post_eddy.eddy_mbs_first_order_fields.nii.gz $qc_eddy/eddy_mbs_first_order_fields.nii.gz
cp eddy_mask.nii $qc_eddy/eddy_mask.nii

#rician bias correction, smoothing, and model fitting with pydesigner
cd $designerdir
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif pydesigner -s --resume --verbose -o $designerdir $rawdwi.nii.gz
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif tensor2metric $designerdir/metrics/DT.nii -vector $designerdir/metrics/dti_V1.nii -modulate none -force

rm -rf $designerdir/tmp/




