#!/bin/bash
#SBATCH --mail-user=rf2485@nyulangone.org
#SBATCH --mail-type=ALL
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --array=1-328

basedir=/gpfs/data/lazarlab/CamCan995
dirS=$basedir/raw
outdir=$basedir/derivatives/camcan_scd_dMRI_paper/recon-all-clinical

mkdir -p $outdir

subj_list=$(cut -f1 anat_over_55.tsv)
subj_list=($subj_list)
subj_num=$(($SLURM_ARRAY_TASK_ID-1))
subj=${subj_list[$subj_num]}

module load freesurfer/7.4.1
export SUBJECTS_DIR=$outdir
recon-all-clinical.sh ${dirS}/${subj}/anat/${subj}_T1w.nii.gz $subj 4 $outdir
mkdir -p $outdir/$subj/mri/orig
mri_convert ${dirS}/${subj}/anat/${subj}_T1w.nii.gz $outdir/$subj/mri/orig/001.mgz
mv $outdir/$subj/surf/lh.pial $outdir/$subj/surf/lh.pial.T1
mv $outdir/$subj/surf/rh.pial $outdir/$subj/surf/rh.pial.T1
recon-all -T2 $dirS/$subj/anat/${subj}_T2w.nii.gz -motioncor -talairach -nuintensitycor -normalization -gcareg -maskbfs -T2pial -cortribbon -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -pctsurfcon -hyporelabel -aparc2aseg -apas2aseg -segstats -wmparc -balabels -subjid ${subj} -sd ${outdir} -threads 4
