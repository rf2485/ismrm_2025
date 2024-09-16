basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/designer_tbss/

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
  
for j in $(cut -f1 $projectdir/dwi_over_55_ctl.tsv); do
	echo "copying files for ${j}"
	cp $projectdir/dwi_processed/$j/metrics/dti_fa.nii $projectdir/tbss/ctl_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dti_md.nii $projectdir/tbss/MD/ctl_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dti_rd.nii $projectdir/tbss/RD/ctl_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dti_ad.nii $projectdir/tbss/AxD/ctl_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dki_kfa.nii $projectdir/tbss/KFA/ctl_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dki_mk.nii $projectdir/tbss/MK/ctl_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dki_rk.nii $projectdir/tbss/RK/ctl_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dki_ak.nii $projectdir/tbss/AK/ctl_${j}.nii
	cp $projectdir/dwi_processed/$j/AMICO/NODDI/fit_FWF.nii.gz $projectdir/tbss/FWF/ctl_${j}.nii.gz
	cp $projectdir/dwi_processed/$j/AMICO/NODDI/fit_NDI.nii.gz $projectdir/tbss/NDI/ctl_${j}.nii.gz
	cp $projectdir/dwi_processed/$j/AMICO/NODDI/fit_ODI.nii.gz $projectdir/tbss/ODI/ctl_${j}.nii.gz
done

for j in $(cut -f1 $projectdir/dwi_over_55_scd.tsv); do
	echo "copying files for ${j}"
	cp $projectdir/dwi_processed/$j/metrics/dti_fa.nii $projectdir/tbss/scd_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dti_md.nii $projectdir/tbss/MD/scd_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dti_rd.nii $projectdir/tbss/RD/scd_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dti_ad.nii $projectdir/tbss/AxD/scd_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dki_kfa.nii $projectdir/tbss/KFA/scd_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dki_mk.nii $projectdir/tbss/MK/scd_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dki_rk.nii $projectdir/tbss/RK/scd_${j}.nii
	cp $projectdir/dwi_processed/$j/metrics/dki_ak.nii $projectdir/tbss/AK/scd_${j}.nii
	cp $projectdir/dwi_processed/$j/AMICO/NODDI/fit_FWF.nii.gz $projectdir/tbss/FWF/scd_${j}.nii.gz
	cp $projectdir/dwi_processed/$j/AMICO/NODDI/fit_NDI.nii.gz $projectdir/tbss/NDI/scd_${j}.nii.gz
	cp $projectdir/dwi_processed/$j/AMICO/NODDI/fit_ODI.nii.gz $projectdir/tbss/ODI/scd_${j}.nii.gz
done

cd $projectdir/tbss
# using fsl

tbss_1_preproc *.nii
tbss_2_reg -T
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
fsl_sub -T 239 -R 32 -j $most_recent_job -l tbss_logs tbss_3_postreg -S
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
fsl_sub -T 239 -R 32 -j $most_recent_job -l tbss_logs tbss_4_prestats 0.2
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
fsl_sub -T 239 -R 32 -j $most_recent_job -l tbss_logs -t $projectdir/tbss_non_FA_array.txt 
most_recent_job=$(squeue -u rf2485 --nohead --format %F | head -n 1)
cd $projectdir/tbss/stats
fsl_sub -T 239 -R 64 -j $most_recent_job -l tbss_logs -t $projectdir/randomise_array.txt 
