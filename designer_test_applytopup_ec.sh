#!/bin/bash
#SBATCH --mail-user=rf2485@nyulangone.org
#SBATCH --mail-type=ALL
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4
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
designerdir=$projectdir/designer_applytopup_ec/$j/
intdir=$designerdir/intermediate_nifti/
mkdir -p $intdir
synb0in=$designerdir/synb0/INPUTS/
mkdir -p $synb0in
synb0out=$designerdir/synb0/OUTPUTS/
mkdir -p $synb0out

module load singularity/3.9.8
module load cuda/11.8
module load miniconda3/gpu/4.9.2
#conda create, singularity pulls, mv *.sif, and cp ec_plot.sh only need to be done once
# singularity pull docker://dmri/neurodock
# singularity pull docker://nyudiffusionmri/designer2
# singularity pull docker://leonyichencai/synb0-disco:v3.1
# mv *.sif $basedir
# conda create -c https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/public/ -c conda-forge -n fsl_eddy fsl-topup==2203.5 fsl-avwutils==2209.2 fsl-fdt==2202.10
source activate ~/.conda/envs/fsl_eddy/
export FSLDIR=$CONDA_PREFIX
source $FSLDIR/etc/fslconf/fsl.sh
# cp $projectdir/ec_plot.sh $FSLDIR/bin/

#concatenate and convert raw dwi
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $rawdwi.json -fslgrad $rawdwi.bvec $rawdwi.bval $rawdwi.nii.gz $designerdir/working.mif -force
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert $designerdir/working.mif -json_export $designerdir/dwi_raw.json -export_grad_fsl $designerdir/dwi_raw.bvec $designerdir/dwi_raw.bval $designerdir/dwi_raw.nii -force

#denoise, degibbs, and normalize with designer
singularity exec --nv --bind $basedir $basedir/designer2_latest.sif designer -denoise -shrinkage frob -adaptive_patch -degibbs -nthreads 4 -nocleanup -scratch $designerdir/tmp $designerdir/dwi_raw.nii $intdir/2_dwi_degibbs.nii

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

#copy files for eddy_correct
cp $synb0out/b0_all.mif $designerdir/tmp/se_epi.mif
cd $designerdir/tmp
cp $designerdir/working.mif dwi.mif

#eddy_correct
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi.mif dwi.nii -strides -1,+2,+3,+4 -json_export dwi.json -export_grad_fsl dwi.bvec dwi.bval
eddy_correct dwi dwi_post_eddy 0 -trilinear -noresampleblur
fdt_rotate_bvecs dwi.bvec dwi_post_eddy.bvec dwi_post_eddy.ecclog
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi_post_eddy.nii.gz dwi_post_eddy.mif -json_import dwi.json -fslgrad dwi_post_eddy.bvec dwi.bval

#plot motion
$FSLDIR/bin/ec_plot.sh dwi_post_eddy.ecclog
cp *.png $designerdir/metrics_qc/eddy/

#prepare for topup
##replace first b0 of se_epi with first b0 of dwi
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi_post_eddy.mif dwi_first_bzero.mif -coord 3 0 -axes 0,1,2
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert se_epi.mif - -coord 3 1 | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrcat dwi_first_bzero.mif - se_epi_firstdwibzero.mif -axis 3
##create files for topup input
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert se_epi_firstdwibzero.mif topup_in.nii -strides -1,+2,+3,+4 -export_pe_table topup_datain.txt

#topup
topup --imain=topup_in.nii --datain=topup_datain.txt --out=field --fout=field_map.nii.gz --config=${FSLDIR}/etc/flirtsch/b02b0.cnf --verbose
##export files for applytopup
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrinfo dwi_post_eddy.mif -export_pe_eddy applytopup_config.txt applytopup_indices.txt
##applytopup
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif applytopup --imain=dwi_post_eddy.nii.gz --datain=applytopup_config.txt --inindex=1 --topup=field --out=dwi_applytopup --method=jac
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi_applytopup.nii.gz dwi_applytopup.mif -json_import dwi.json -fslgrad dwi_post_eddy.bvec dwi.bval

#move and convert eddy output
intermediate=$designerdir/intermediate_nifti/2_dwi_undistorted
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -export_grad_fsl $intermediate.bvec $intermediate.bval -json_export $intermediate.json dwi_applytopup.mif $intermediate.nii -force
mv dwi_applytopup.mif $designerdir/working.mif

#rician bias correction, smoothing, and model fitting with pydesigner
cd $designerdir
# rm -rf $designerdir/tmp/
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif pydesigner -s --resume --verbose --noqc --nthreads 4 -o $designerdir $rawdwi.nii.gz
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif tensor2metric $designerdir/metrics/DT.nii -vector $designerdir/metrics/dti_V1.nii -modulate none -force




