#!/bin/bash
#SBATCH --mail-user=rf2485@nyulangone.org
#SBATCH --mail-type=ALL
#SBATCH	--gres=gpu:1 -p radiology,gpu4_short,gpu4_medium,gpu4_long,gpu8_short,gpu8_medium,gpu8_long
#SBATCH --time=03:00:00
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

singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $rawdwi.json -fslgrad $rawdwi.bvec $rawdwi.bval $rawdwi.nii.gz $designerdir/working.mif
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert $designerdir/working.mif -json_export $designerdir/dwi_raw.json -export_grad_fsl $designerdir/dwi_raw.bvec $designerdir/dwi_raw.bval $designerdir/dwi_raw.nii

singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif dwidenoise -noise $designerdir/noisemap.nii $designerdir/working.mif $intdir/1_dwi_denoised.mif
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert $intdir/1_dwi_denoised.mif -json_export $intdir/1_dwi_denoised.json -export_grad_fsl $intdir/1_dwi_denoised.bvec $intdir/1_dwi_denoised.bval $intdir/1_dwi_denoised.nii
mv $intdir/1_dwi_denoised.mif $designerdir/working.mif

# singularity exec --nv --bind $basedir $basedir/designer2_latest.sif designer -degibbs $intdir/1_dwi_denoised.nii $intdir/2_dwi_degibbs.nii
# cp $intdir/1_dwi_denoised.json $intdir/2_dwi_degibbs.json
# singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $intdir/2_dwi_degibbs.json -fslgrad $intdir/2_dwi_degibbs.bvec $intdir/2_dwi_degibbs.bval $intdir/2_dwi_degibbs.nii $designerdir/working.mif -force

singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif dwiextract -bzero $designerdir/working.mif - | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert - -coord 3 0 -axes 0,1,2 $intdir/b0_1_degibbs.mif
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -export_pe_table $synb0in/acqparams.txt $intdir/b0_1_degibbs.mif $synb0in/b0.nii.gz -force
echo " 0 1 0 0.000" >> $synb0in/acqparams.txt
cp $rawT1.nii.gz $synb0in/T1.nii.gz
singularity run -e -B $synb0in:/INPUTS -B $synb0out:/OUTPUTS -B $basedir/license.txt:/extra/freesurfer/license.txt $basedir/synb0-disco_v3.1.sif
# echo " 0 1 0 0.000" > $synb0out/acqparams.txt
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -import_pe_table $synb0in/acqparams.txt $synb0out/b0_all.nii.gz $synb0out/b0_all.mif

singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif dwifslpreproc  $designerdir/working.mif -rpe_header -se_epi $synb0out/b0_all.mif -eddy_options "--data_is_shelled --repol --slm=linear" -eddyqc_all $designerdir/metrics_qc/eddy $intdir/3_dwi_undistorted.mif
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_export $intdir/3_dwi_undistorted.json -export_grad_fsl $intdir/3_dwi_undistorted.bvec $intdir/3_dwi_undistorted.bval $intdir/3_dwi_undistorted.mif $intdir/3_dwi_undistorted.nii
mv $intdir/3_dwi_undistorted.mif $designerdir/working.mif

singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif pydesigner -s --resume --verbose --adv -o $designerdir $rawdwi.nii.gz
# singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert $intdir/2_dwi_degibbs.mif -json_export $intdir/2_dwi_degibbs.json -export_grad_fsl $intdir/2_dwi_degibbs.bvec $intdir/2_dwi_degibbs.bval $intdir/2_dwi_degibbs.nii -force

# pydesigner -s --verbose --nthreads 2 -o $designerdir $basedir/raw/$j/dwi/${j}_dwi.nii.gz

# intermediatedir=$designerdir/preproc_intermediate/
#
# module load singularity/3.9.8
# # singularity pull docker://nyudiffusionmri/designer2:main
#
# singularity run --bind $basedir $projectdir/designer2_main.sif designer -denoise -algorithm veraart -degibbs -nocleanup -n_cores 2 -scratch $intermediatedir $rawdir/$j/dwi/${j}_dwi.nii.gz $designerdir/dwi_preproc.nii.gz
#
# #ants motion correction, 6 dof register to first b0
# singularity run --bind $intermediatedir designer2_main.sif mrconvert $intermediatedir/working_rpg.nii -fslgrad $intermediatedir/working.bvec $intermediatedir/working.bval -coord 3 0 -axes 0,1,2 $intermediatedir/first_volume_rpg.nii
# singularity run --bind $projectdir designer2_main.sif python antsmoco.py $intermediatedir
# singularity run --bind $intermediatedir designer2_main.sif mrconvert -force -fslgrad $intermediatedir/working_antsmoco.bvec $intermediatedir/working.bval $intermediatedir/working_antsmoco.nii $intermediatedir/working.mif
#
# #final brainmask
# singularity run --bind $intermediatedir designer2_main.sif dwiextract -bzero $intermediatedir/working.mif - | singularity run --bind $intermediatedir designer2_main.sif mrmath -force -axis 3 - mean $intermediatedir/b0bc.nii
# singularity run --bind $intermediatedir designer2_main.sif bet $intermediatedir/b0bc.nii $intermediatedir/brain.nii.gz -m -f 0.25
# #final preproc output
# singularity run --bind $designerdir designer2_main.sif mrconvert -force -export_grad_fsl $designerdir/dwi_preproc.bvec $designerdir/dwi_preproc.bval -json_export $designerdir/dwi_preproc.json $intermediatedir/working.mif $designerdir/dwi_preproc.nii.gz
#
# #dti and dki
# modeldir=$designerdir/diff_model_fit
# singularity run --bind $designerdir designer2_main.sif tmi -DTI -DKI -SMI -sigma $intermediatedir/noisemap.mif -compartments EAS,IAS,FW -mask $intermediatedir/brain_mask.nii.gz -nocleanup -n_cores 2 -scratch $modeldir/model_intermediate -echo_time 0.104 $designerdir/dwi_preproc.nii.gz $modeldir
#

# module load miniconda3/gpu/4.9.2
# # conda create -n camcan python=3.7
# conda activate camcan
# # pip install packaging
# # conda install numpy
# # pip install PyDesigner-DWI==1.0.0 --user
# # conda install -c conda-forge pybids
# # conda install -c mrtrix3 mrtrix3
# # conda install pandas
# # pip install dmri-amico==2.0.1
# # sed '1d' dwi_over_55.tsv > subjectsfile.txt
# module load fsl/.6.0.6
# export LD_LIBRARY_PATH=/lib
#
