metric_list=(FA MD AxD RD KFA MK AK RK FWF NDI ODI Da_smi DePar_smi DePerp_smi f_smi p2_smi)
basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/scd/ismrm_2025

module load miniconda3/gpu/4.9.2
source activate ~/.conda/envs/fsl_eddy/
export FSLDIR=$CONDA_PREFIX
source $FSLDIR/etc/fslconf/fsl.sh

cd $projectdir/tbss/stats

for metric in "${metric_list[@]}"; do
	fsleyes -std1mm all_${metric} mean_FA_skeleton_mask -cm green ${metric}_clusterm_corrp_tstat1 -cm blue -dr 0.949 1 ${metric}_clusterm_corrp_tstat2 -cm red -dr 0.949 1
done

#no covariates
cd $projectdir/tbss/stats
for metric in "${metric_list[@]}"; do
	fsleyes -std1mm all_${metric} mean_FA_skeleton_mask -cm green ${metric}_clusterm_corrp_tstat1 -cm blue ${metric}_clusterm_corrp_tstat2 -cm red #red means higher in SCD (tstat2)
done

covariate_list=(age_int anxiety_int bmi_int depression_int memory_int)
for cov in "${covariate_list[@]}"; do
	for metric in "${metric_list[@]}"; do
		fsleyes -std1mm mean_FA_skeleton_mask -cm green ${cov}/${cov}_${metric}_clusterm_corrp_tstat1 -cm blue ${cov}/${cov}_${metric}_clusterm_corrp_tstat2 -cm red #red means higher in SCD (tstat2)
		fsleyes -std1mm mean_FA_skeleton_mask -cm green ${cov}/${cov}_${metric}_clusterm_corrp_tstat3 -cm blue ${cov}/${cov}_${metric}_clusterm_corrp_tstat4 -cm red #red means SCD has a steeper slope than controls (tstat4)
		fsleyes -std1mm mean_FA_skeleton_mask -cm green ${cov}/${cov}_${metric}_clusterm_corrp_tstat5 -cm red ${cov}/${cov}_${metric}_clusterm_corrp_tstat6 -cm blue #red means positive slope across groups
		fsleyes -std1mm mean_FA_skeleton_mask -cm green ${cov}/${cov}_${metric}_clusterm_corrp_tstat7 -cm red ${cov}/${cov}_${metric}_clusterm_corrp_tstat8 -cm blue #red means positive slope in controls
		fsleyes -std1mm mean_FA_skeleton_mask -cm green ${cov}/${cov}_${metric}_clusterm_corrp_tstat9 -cm red ${cov}/${cov}_${metric}_clusterm_corrp_tstat10 -cm blue #red means positive slope in SCD
	done
done