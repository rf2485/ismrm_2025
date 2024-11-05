#!/bin/bash
#SBATCH --mail-user=rf2485@nyulangone.org
#SBATCH --mail-type=ALL
#SBATCH --time=12:00:00
#SBATCH --mem=32G
#SBATCH --array=1-325
#SBATCH -o ./slurm_output/3_process_dwi/slurm-%A_%a.out

basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/designer_tbss/

subj_list=$(cut -f1 -d$'\t' $projectdir/dwi_over_55.tsv)
subj_list=($subj_list)
subj_num=$(($SLURM_ARRAY_TASK_ID))
j=${subj_list[$subj_num]}

designerdir=$projectdir/dwi_processed/$j/
intdir=$designerdir/intermediate_nifti/

module load singularity/3.9.8
module load miniconda3/gpu/4.9.2
source activate ~/.conda/envs/fsl_eddy/
export FSLDIR=$CONDA_PREFIX
source $FSLDIR/etc/fslconf/fsl.sh

singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $intdir/2_dwi_degibbs.json -fslgrad $intdir/2_dwi_degibbs.bvec $intdir/2_dwi_degibbs.bval $intdir/2_dwi_degibbs.nii $designerdir/working.mif -force

mkdir -p $designerdir/tmp
cd $designerdir/tmp
cp $designerdir/working.mif dwi.mif
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi.mif dwi.nii -strides -1,+2,+3,+4 -json_export dwi.json -export_grad_fsl dwi.bvec dwi.bval
eddy_correct dwi dwi_post_eddy 0 -trilinear -noresampleblur

logfile=dwi_post_eddy.ecclog
basenm=`basename $logfile .ecclog`
nums=`grep -n 'Final' $logfile | sed 's/:.*//'`

touch grot_ts.txt
touch grot.mat

firsttime=yes;
m=1;
for n in $nums ; do 
    echo "Timepoint $m"
    n1=`echo $n + 1 | bc` ; 
    n2=`echo $n + 5 | bc` ;
    sed -n  "$n1,${n2}p" $logfile > grot.mat ; 
    if [ $firsttime = yes ] ; then firsttime=no; cp grot.mat grot.refmat ; cp grot.mat grot.oldmat ; fi
    absval=`rmsdiff grot.mat grot.refmat $basenm`;
    relval=`rmsdiff grot.mat grot.oldmat $basenm`;
    cp grot.mat grot.oldmat
    echo $absval $relval >> ec_disp.txt ;
    avscale --allparams grot.mat $basenm | grep 'Rotation Angles' | sed 's/.* = //' >> ec_rot.txt ;
    avscale --allparams grot.mat $basenm | grep 'Translations' | sed 's/.* = //' >> ec_trans.txt ;
    m=`echo $m + 1 | bc`;
done

echo "absolute" > grot_labels.txt
echo "relative" >> grot_labels.txt

fsl_tsplot -i ec_disp.txt -t 'Eddy Current estimated mean displacement (mm)' -l grot_labels.txt -o ec_disp.png

echo "x" > grot_labels.txt
echo "y" >> grot_labels.txt
echo "z" >> grot_labels.txt

fsl_tsplot -i ec_rot.txt -t 'Eddy Current estimated rotations (radians)' -l grot_labels.txt -o ec_rot.png
fsl_tsplot -i ec_trans.txt -t 'Eddy Current estimated translations (mm)' -l grot_labels.txt -o ec_trans.png

mkdir -p $designerdir/metrics_qc/eddy
cp ec* $designerdir/metrics_qc/eddy/
cp dwi_post_eddy.ecclog $designerdir/metrics_qc/eddy/
cd $designerdir/
rm -rf $designerdir/tmp

