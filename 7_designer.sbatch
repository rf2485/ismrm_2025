#!/bin/bash
#SBATCH --mail-user=rf2485@nyulangone.org
#SBATCH --mail-type=ALL
#SBATCH	--gres=gpu:1 -p radiology,gpu4_short,gpu4_medium,gpu4_long,gpu8_short,gpu8_medium,gpu8_long
#SBATCH --time=12:00:00
#SBATCH --mem=32G
#SBATCH --array=1-325
#SBATCH -o ./slurm_output/7_designer/slurm-%A_%a.out


basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/designer_tbss/

subj_list=$(cut -f1 -d$'\t' $projectdir/dwi_over_55.tsv)
subj_list=($subj_list)
subj_num=$(($SLURM_ARRAY_TASK_ID))
j=${subj_list[$subj_num]}

rawdwi=$basedir/raw/$j/dwi/${j}_dwi
rawT1=$basedir/raw/$j/anat/${j}_T1w
designerdir=$projectdir/designer/$j/
intdir=$designerdir/intermediate_nifti/
mkdir -p $intdir
synb0in=$designerdir/synb0/INPUTS/
mkdir -p $synb0in
synb0out=$designerdir/synb0/OUTPUTS/
mkdir -p $synb0out

module load singularity/3.9.8
module load cuda/11.8

# singularity pull docker://dmri/neurodock
# mv neurodock_latest.sif $basedir
# singularity pull docker://nyudiffusionmri/designer2
# mv designer2_latest.sif $basedir
# singularity pull docker://leonyichencai/synb0-disco:v3.1
# mv synb0-disco_v3.1.sif $basedir

singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $rawdwi.json -fslgrad $rawdwi.bvec $rawdwi.bval $rawdwi.nii.gz $designerdir/working.mif -force
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert $designerdir/working.mif -json_export $designerdir/dwi_raw.json -export_grad_fsl $designerdir/dwi_raw.bvec $designerdir/dwi_raw.bval $designerdir/dwi_raw.nii -force

# singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif dwidenoise -noise $designerdir/noisemap.nii $designerdir/working.mif $intdir/1_dwi_denoised.mif
# singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert $intdir/1_dwi_denoised.mif -json_export $intdir/1_dwi_denoised.json -export_grad_fsl $intdir/1_dwi_denoised.bvec $intdir/1_dwi_denoised.bval $intdir/1_dwi_denoised.nii
# mv $intdir/1_dwi_denoised.mif $designerdir/working.mif

singularity exec --nv --bind $basedir $basedir/designer2_latest.sif designer -denoise -shrinkage frob -adaptive_patch -degibbs -nocleanup -scratch $designerdir/tmp $designerdir/dwi_raw.nii $intdir/2_dwi_degibbs.nii
mv $designerdir/tmp/sigma.nii $designerdir/noisemap.nii
mv $designerdir/tmp/tmp_dwidn.nii $intdir/1_dwi_denoised.nii
cp $designerdir/dwi_raw.json $intdir/1_dwi_denoised.json
cp $designerdir/dwi_raw.bvec $intdir/1_dwi_denoised.bvec
cp $designerdir/dwi_raw.bval $intdir/1_dwi_denoised.bval
cp $designerdir/dwi_raw.json $intdir/2_dwi_degibbs.json
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $intdir/2_dwi_degibbs.json -fslgrad $intdir/2_dwi_degibbs.bvec $intdir/2_dwi_degibbs.bval $intdir/2_dwi_degibbs.nii $designerdir/working.mif -force
rm -rf $designerdir/tmp/

singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif dwiextract -bzero $designerdir/working.mif - | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert - -coord 3 0 -axes 0,1,2 $intdir/b0_1_working.mif
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -export_pe_table $synb0in/acqparams.txt $intdir/b0_1_working.mif $synb0in/b0.nii.gz -force
rm $intdir/b0_1_working.mif
echo " 0 1 0 0.000" >> $synb0in/acqparams.txt
cp $rawT1.nii.gz $synb0in/T1.nii.gz
singularity run -e -B $synb0in:/INPUTS -B $synb0out:/OUTPUTS -B $basedir/license.txt:/extra/freesurfer/license.txt $basedir/synb0-disco_v3.1.sif
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -import_pe_table $synb0in/acqparams.txt $synb0out/b0_all.nii.gz $synb0out/b0_all.mif -force

mkdir -p $designerdir/metrics_qc/eddy/
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif dwiextract -bzero $designerdir/working.mif - | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrmath - mean $intdir/b0_mean_working.nii -axis 3
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif bet $intdir/b0_mean_working $intdir/b0_mean_working_brain -m -f 0.2
rm $intdir/b0_mean_working.nii
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif maskfilter $intdir/b0_mean_working_brain_mask.nii.gz dilate $designerdir/metrics_qc/eddy/eddy_mask.nii -force
rm $intdir/*.nii.gz
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif dwifslpreproc $designerdir/working.mif -rpe_header -se_epi $synb0out/b0_all.mif -align_seepi -eddy_options "--data_is_shelled --repol --slm=linear" -eddyqc_all $designerdir/metrics_qc/eddy -eddy_mask $designerdir/metrics_qc/eddy/eddy_mask.nii $intdir/2_dwi_undistorted.mif -force
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_export $intdir/2_dwi_undistorted.json -export_grad_fsl $intdir/2_dwi_undistorted.bvec $intdir/2_dwi_undistorted.bval $intdir/2_dwi_undistorted.mif $intdir/2_dwi_undistorted.nii -force
mv $intdir/2_dwi_undistorted.mif $designerdir/working.mif

singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif pydesigner -s --akc --median --resume --verbose -o $designerdir $rawdwi.nii.gz
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif tensor2metric $designerdir/metrics/DT.nii -vector $designerdir/metrics/dti_V1.nii -modulate none