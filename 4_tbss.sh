basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/scd/ismrm_2025

module load miniconda3/gpu/4.9.2
source activate ~/.conda/envs/fsl_eddy/
export FSLDIR=$CONDA_PREFIX
source $FSLDIR/etc/fslconf/fsl.sh
module load r/4.3.2

problem_subjs=( scd_sub-CC510255 scd_sub-CC620821 ctl_sub-CC510438 ctl_sub-CC621011 ctl_sub-CC710551 ctl_sub-CC721292 )
# 510255 has pathology in the L temporal lobe causing errors in registration to template
# sub-CC510438 has pathology in L frontal lobe
# sub-CC710551 has motion artifacts in DWI
# 620821, 621011, and 721292 have big ventricles, causing errors in registration to template

meas_list=( dki_ak dki_kfa dki_mk dki_mkt dki_rk dti_ad dti_fa dti_md dti_rd smi_matlab_f smi_matlab_Da smi_matlab_DePar smi_matlab_DePerp smi_matlab_p2 wm_fit_FWF wm_fit_NDI wm_fit_ODI )

#create stats contrasts and matrices
mkdir -p $projectdir/tbss/stats
mkdir -p $projectdir/tbss_ctl/stats
mkdir -p $projectdir/tbss_scd/stats
Rscript fsl_glm_matrices.R

#copy FA files to TBSS folder
for j in $(cut -f1 $projectdir/dwi_over_55_ctl.tsv); do
	echo "copying non-masked FA files for ${j} for constructing the WM skeleton"
	fslmaths $projectdir/freesurfer/$j/diffusion/dti_fa.nii.gz -nan $projectdir/tbss/ctl_${j}.nii.gz
done
for j in $(cut -f1 $projectdir/dwi_over_55_scd.tsv); do
	echo "copying non-masked FA files for ${j} for constructing the WM skeleton"
	fslmaths $projectdir/freesurfer/$j/diffusion/dti_fa.nii.gz -nan $projectdir/tbss/scd_${j}.nii.gz
done

#copy non-FA diffusion files to TBSS folder
for meas in "${meas_list[@]}"; do
	mkdir -p $projectdir/tbss/$meas
	for j in $(cut -f1 $projectdir/dwi_over_55_ctl.tsv); do
		echo "copying ${meas} files for ${j}"
		fslmaths $projectdir/freesurfer/$j/diffusion/${meas}_masked_wm.nii.gz -nan $projectdir/tbss/$meas/ctl_${j}.nii.gz
	done
	for j in $(cut -f1 $projectdir/dwi_over_55_scd.tsv); do
		echo "copying ${meas} files for ${j}"
		fslmaths $projectdir/freesurfer/$j/diffusion/${meas}_masked_wm.nii.gz -nan $projectdir/tbss/$meas/scd_${j}.nii.gz
	done
done

#remove problem subjects
for subj in "${problem_subjs[@]}"; do
	echo "removing ${subj}"
	rm $projectdir/tbss/${subj}.nii.gz
	rm $projectdir/tbss/*/${subj}.nii.gz
done

#complete TBSS pipeline
cd $projectdir/tbss
tbss_1_preproc *.nii.gz
tbss_2_reg -T
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
fsl_sub -T 239 -R 32 -j $most_recent_job -l tbss_logs tbss_3_postreg -S
# fsleyes $tbssdir/stats/all_FA -dr 0 1 $tbssdir/stats/mean_FA_skeleton -dr 0.2 1 -cm green
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
fsl_sub -T 239 -R 32 -j $most_recent_job -l tbss_logs tbss_4_prestats 0.3
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
fsl_sub -T 239 -R 64 -j $most_recent_job -l tbss_logs -t $projectdir/dwi_non_FA_array
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)

#stats
cd $projectdir/tbss/stats
design_ttest2 design 194 125
Text2Vest interaction_con.txt interaction.con
int_test_list=(memory_int age_int)
for test in "${int_test_list[@]}"; do
	Text2Vest ${test}_mat.txt ${test}.mat
	mkdir ${test}
done
fsl_sub -T 719 -R 64 -j $most_recent_job -l tbss_logs -t $projectdir/dwi_randomise_array