basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/scd/ismrm_2025

module load miniconda3/gpu/4.9.2
source activate ~/.conda/envs/fsl_eddy/
export FSLDIR=$CONDA_PREFIX
source $FSLDIR/etc/fslconf/fsl.sh

mkdir -p $projectdir/tbss/stats
mkdir $projectdir/tbss/MD
mkdir $projectdir/tbss/RD
mkdir $projectdir/tbss/AxD
mkdir $projectdir/tbss/KFA
mkdir $projectdir/tbss/MK
mkdir $projectdir/tbss/RK
mkdir $projectdir/tbss/AK
mkdir $projectdir/tbss/FWF
mkdir $projectdir/tbss/NDI
mkdir $projectdir/tbss/ODI
mkdir $projectdir/tbss/Da_smi
mkdir $projectdir/tbss/DePar_smi
mkdir $projectdir/tbss/DePerp_smi
mkdir $projectdir/tbss/f_smi
mkdir $projectdir/tbss/p2_smi
 
for j in $(cut -f1 $projectdir/dwi_over_55_ctl.tsv); do
	echo "copying files for ${j}"
	fslmaths $projectdir/dwi_processed/$j/metrics/dti_fa.nii -nan $projectdir/tbss/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dti_md.nii -nan $projectdir/tbss/MD/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dti_rd.nii -nan $projectdir/tbss/RD/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dti_ad.nii -nan $projectdir/tbss/AxD/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dki_kfa.nii -nan $projectdir/tbss/KFA/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dki_mk.nii -nan $projectdir/tbss/MK/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dki_rk.nii -nan $projectdir/tbss/RK/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dki_ak.nii -nan $projectdir/tbss/AK/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/smi_matlab_Da.nii -nan $projectdir/tbss//Da_smi/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics//smi_matlab_DePar.nii -nan $projectdir/tbss//DePar_smi/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/smi_matlab_DePerp.nii -nan $projectdir/tbss/DePerp_smi/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/smi_matlab_f.nii -nan $projectdir/tbss/f_smi/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/smi_matlab_p2.nii -nan $projectdir/tbss/p2_smi/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/AMICO/NODDI/fit_FWF.nii.gz -nan $projectdir/tbss/FWF/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/AMICO/NODDI/fit_NDI.nii.gz -nan $projectdir/tbss/NDI/ctl_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/AMICO/NODDI/fit_ODI.nii.gz -nan $projectdir/tbss/ODI/ctl_${j}.nii.gz
done

for j in $(cut -f1 $projectdir/dwi_over_55_scd.tsv); do
	echo "copying files for ${j}"
	fslmaths $projectdir/dwi_processed/$j/metrics/dti_fa.nii -nan $projectdir/tbss/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dti_md.nii -nan $projectdir/tbss/MD/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dti_rd.nii -nan $projectdir/tbss/RD/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dti_ad.nii -nan $projectdir/tbss/AxD/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dki_kfa.nii -nan $projectdir/tbss/KFA/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dki_mk.nii -nan $projectdir/tbss/MK/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dki_rk.nii -nan $projectdir/tbss/RK/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/dki_ak.nii -nan $projectdir/tbss/AK/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/smi_matlab_Da.nii -nan $projectdir/tbss//Da_smi/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics//smi_matlab_DePar.nii -nan $projectdir/tbss//DePar_smi/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/smi_matlab_DePerp.nii -nan $projectdir/tbss/DePerp_smi/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/smi_matlab_f.nii -nan $projectdir/tbss/f_smi/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/metrics/smi_matlab_p2.nii -nan $projectdir/tbss/p2_smi/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/AMICO/NODDI/fit_FWF.nii.gz -nan $projectdir/tbss/FWF/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/AMICO/NODDI/fit_NDI.nii.gz -nan $projectdir/tbss/NDI/scd_${j}.nii.gz
	fslmaths $projectdir/dwi_processed/$j/AMICO/NODDI/fit_ODI.nii.gz -nan $projectdir/tbss/ODI/scd_${j}.nii.gz
done

problem_subjs=( scd_sub-CC510255 scd_sub-CC620821 ctl_sub-CC621011 ctl_sub-CC721292 )
# 510255 has pathology in the L temporal lobe causing errors in registration to template
# 620821, 621011, and 721292 have big ventricles, causing errors in registration to template
for subj in "${problem_subjs[@]}"; do
	echo "removing ${subj}"
	rm $projectdir/tbss/${subj}.nii.gz
	rm $projectdir/tbss/*/${subj}.nii.gz
done

cd $projectdir/tbss
tbss_1_preproc *.nii.gz
rm -rf $projectdir/dwi_processed/group_qc/metrics/dti_fa
cp -r $projectdir/tbss/FA/slicesdir $projectdir/dwi_processed/group_qc/metrics/dti_fa
tbss_2_reg -T
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
fsl_sub -T 239 -R 32 -j $most_recent_job -l tbss_logs tbss_3_postreg -S
# fsleyes $tbssdir/stats/all_FA -dr 0 1 $tbssdir/stats/mean_FA_skeleton -dr 0.2 1 -cm green
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
fsl_sub -T 239 -R 32 -j $most_recent_job -l tbss_logs tbss_4_prestats 0.3
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
fsl_sub -T 239 -R 64 -j $most_recent_job -l tbss_logs -t $projectdir/tbss_non_FA_array
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
cd $projectdir/tbss/stats
design_ttest2 design 196 125
fsl_sub -T 239 -R 64 -j $most_recent_job -l tbss_logs -t $projectdir/randomise_array
