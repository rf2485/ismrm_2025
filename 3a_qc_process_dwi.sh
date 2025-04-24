basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/designer_tbss/
dwidir=$projectdir/dwi_processed/

module load miniconda3/gpu/4.9.2
source activate ~/.conda/envs/fsl_eddy/
export FSLDIR=$CONDA_PREFIX
source $FSLDIR/etc/fslconf/fsl.sh

subj_list=$(cut -f1 $projectdir/dwi_over_55.tsv)
subj_list=($subj_list)

mkdir -p $dwidir/group_qc/intermediate_nifti
mkdir -p $dwidir/group_qc/metrics

nii_list=( dwi_raw noisemap residual intermediate_nifti/1_dwi_denoised intermediate_nifti/2_dwi_degibbs intermediate_nifti/2_dwi_undistorted intermediate_nifti/3_dwi_smoothed intermediate_nifti/4_dwi_rician B0 B1000 B2000 metrics/dti_md metrics/dti_rd metrics/dti_ad metrics/dki_mk metrics/dki_rk metrics/dki_ak metrics/dki_kfa metrics/dki_mkt metrics/wmti_awf metrics/wmti_eas_ad metrics/wmti_eas_rd metrics/wmti_eas_tort metrics/wmti_ias_da metrics/smi_matlab_Da metrics/smi_matlab_DePar metrics/smi_matlab_DePerp metrics/smi_matlab_f metrics/smi_matlab_p2 )
for i in "${nii_list[@]}"; do
	slicesdir $dwidir/*/${i}.nii
	rm -rf $dwidir/group_qc/$i
	mv slicesdir $dwidir/group_qc/$i
done

mkdir -p $dwidir/group_qc/brain_mask
mkdir -p $dwidir/group_qc/csf_mask
for subj in "${subj_list[@]}"; do
	echo $subj
	cp $dwidir/$subj/B0.nii $dwidir/group_qc/brain_mask/${subj}_1_B0.nii
	cp $dwidir/$subj/brain_mask.nii $dwidir/group_qc/brain_mask/${subj}_2_brain_mask.nii
	cp $dwidir/$subj/B0.nii $dwidir/group_qc/csf_mask/${subj}_1_B0.nii
	cp $dwidir/$subj/csf_mask.nii $dwidir/group_qc/csf_mask/${subj}_2_csf_mask.nii
done
slicesdir -o $dwidir/group_qc/brain_mask/*.nii
rm -rf $dwidir/group_qc/brain_mask/
mv slicesdir $dwidir/group_qc/brain_mask
slicesdir -o $dwidir/group_qc/csf_mask/*.nii
rm -rf $dwidir/group_qc/csf_mask/
mv slicesdir $dwidir/group_qc/csf_mask

noddi_list=( AMICO/NODDI/fit_FWF AMICO/NODDI/fit_NDI AMICO/NODDI/fit_ODI )
mkdir -p $dwidir/group_qc/AMICO/NODDI
for  i in "${noddi_list[@]}"; do
	slicesdir $dwidir/*/${i}.nii.gz
	rm -rf $dwidir/group_qc/$i
	mv slicesdir $dwidir/group_qc/$i
done