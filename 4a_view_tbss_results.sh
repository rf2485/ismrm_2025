metric_list=(FA MD AxD RD KFA MK AK RK FWF NDI ODI Da_smi DePar_smi DePerp_smi f_smi p2_smi)
basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/designer_tbss/

module load miniconda3/gpu/4.9.2
source activate ~/.conda/envs/fsl_eddy/
export FSLDIR=$CONDA_PREFIX
source $FSLDIR/etc/fslconf/fsl.sh

cd $projectdir/tbss/stats

for metric in "${metric_list[@]}"; do
	fsleyes -std1mm all_${metric} mean_FA_skeleton_mask -cm green ${metric}_clusterm_corrp_tstat1 -cm blue-lightblue -dr 0.949 1 ${metric}_clusterm_corrp_tstat2 -cm red-yellow -dr 0.949 1
done
