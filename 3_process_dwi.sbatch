#!/bin/bash
#SBATCH --mail-user=rf2485@nyulangone.org
#SBATCH --mail-type=ALL
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4
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

rawdwi=$basedir/raw/$j/dwi/${j}_dwi
rawT1=$basedir/raw/$j/anat/${j}_T1w
designerdir=$projectdir/dwi_processed/$j/
intdir=$designerdir/intermediate_nifti/
mkdir -p $intdir
synb0in=$designerdir/synb0/INPUTS/
mkdir -p $synb0in
synb0out=$designerdir/synb0/OUTPUTS/
mkdir -p $synb0out

module load singularity/3.9.8
module load freesurfer/7.4.1
module load miniconda3/gpu/4.9.2
source activate ~/.conda/envs/fsl_eddy/
export FSLDIR=$CONDA_PREFIX
source $FSLDIR/etc/fslconf/fsl.sh

#concatenate and convert raw dwi
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $rawdwi.json -fslgrad $rawdwi.bvec $rawdwi.bval $rawdwi.nii.gz $designerdir/working.mif -force
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert $designerdir/working.mif -json_export $designerdir/dwi_raw.json -export_grad_fsl $designerdir/dwi_raw.bvec $designerdir/dwi_raw.bval $designerdir/dwi_raw.nii -force

#denoise, degibbs, and normalize with designer
rm -rf $designerdir/tmp
singularity exec --nv --bind $basedir $basedir/designer2_v2.0.10.sif designer -denoise -shrinkage frob -adaptive_patch -degibbs -nthreads 4 -nocleanup -scratch $designerdir/tmp $designerdir/dwi_raw.nii $intdir/2_dwi_degibbs.nii

#move denoised files and calculate residual
mv $designerdir/tmp/sigma.nii $designerdir/noisemap.nii
mv $designerdir/tmp/tmp_dwidn.nii $intdir/1_dwi_denoised.nii
cp $designerdir/dwi_raw.json $intdir/1_dwi_denoised.json
cp $designerdir/dwi_raw.bvec $intdir/1_dwi_denoised.bvec
cp $designerdir/dwi_raw.bval $intdir/1_dwi_denoised.bval
singularity exec --bind $basedir $basedir/neurodock_latest.sif mrcalc $designerdir/dwi_raw.nii $designerdir/intermediate_nifti/1_dwi_denoised.nii -sub $designerdir/residual.nii

#move and convert degibbsed files
cp $designerdir/dwi_raw.json $intdir/2_dwi_degibbs.json
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -json_import $intdir/2_dwi_degibbs.json -fslgrad $intdir/2_dwi_degibbs.bvec $intdir/2_dwi_degibbs.bval $intdir/2_dwi_degibbs.nii $designerdir/working.mif -force

#prepare for synb0
##create b0 and acqparams
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif dwiextract -bzero $designerdir/working.mif - | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert - -coord 3 0 -axes 0,1,2 $intdir/b0_1_working.mif -force
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -export_pe_table $synb0in/acqparams.txt $intdir/b0_1_working.mif $synb0in/b0.nii.gz -force
rm $intdir/b0_1_working.mif
echo " 0 1 0 0.000" >> $synb0in/acqparams.txt
##copy T1
cp $rawT1.nii.gz $synb0in/T1.nii.gz

#synb0
singularity run -e -B $synb0in:/INPUTS -B $synb0out:/OUTPUTS -B $basedir/license.txt:/extra/freesurfer/license.txt $basedir/synb0-disco_v3.1.sif
##copy and convert synb0 output
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -import_pe_table $synb0in/acqparams.txt $synb0out/b0_all.nii.gz $synb0out/b0_all.mif -force

#copy and convert files for eddy_correct
cp $synb0out/b0_all.mif $designerdir/tmp/se_epi.mif
cd $designerdir/tmp
cp $designerdir/working.mif dwi.mif
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi.mif dwi.nii -strides -1,+2,+3,+4 -json_export dwi.json -export_grad_fsl dwi.bvec dwi.bval

#eddy_correct, using first volume as reference, with no blurring
eddy_correct dwi dwi_post_eddy 0 -trilinear -noresampleblur
##rotate bvecs using eddy_correct transformation log
fdt_rotate_bvecs dwi.bvec dwi_post_eddy.bvec dwi_post_eddy.ecclog
##convert eddy_correct output
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi_post_eddy.nii.gz dwi_post_eddy.mif -json_import dwi.json -fslgrad dwi_post_eddy.bvec dwi.bval

#quantify motion
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

#prepare for topup
##replace first b0 of se_epi with first b0 of dwi
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi_post_eddy.mif dwi_first_bzero.mif -coord 3 0 -axes 0,1,2
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert se_epi.mif - -coord 3 1 | singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrcat dwi_first_bzero.mif - se_epi_firstdwibzero.mif -axis 3
##create files for topup input
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert se_epi_firstdwibzero.mif topup_in.nii -strides -1,+2,+3,+4 -export_pe_table topup_datain.txt

#topup
topup --imain=topup_in.nii --datain=topup_datain.txt --out=field --fout=field_map.nii.gz --config=${FSLDIR}/etc/flirtsch/b02b0.cnf --verbose
##create files for applytopup
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrinfo dwi_post_eddy.mif -export_pe_eddy applytopup_config.txt applytopup_indices.txt
##applytopup
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif applytopup --imain=dwi_post_eddy.nii.gz --datain=applytopup_config.txt --inindex=1 --topup=field --out=dwi_applytopup --method=jac
##convert applytopup output
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert dwi_applytopup.nii.gz dwi_applytopup.mif -json_import dwi.json -fslgrad dwi_post_eddy.bvec dwi.bval
##move and convert applytopup output
intermediate=$designerdir/intermediate_nifti/2_dwi_undistorted
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif mrconvert -export_grad_fsl $intermediate.bvec $intermediate.bval -json_export $intermediate.json dwi_applytopup.mif $intermediate.nii -force
mv dwi_applytopup.mif $designerdir/working.mif

#brain mask
singularity exec --bind $basedir/ $basedir/neurodock_latest.sif dwiextract $designerdir/working.mif - -bzero | singularity exec --bind $basedir/ $basedir/neurodock_latest.sif mrmath - mean - -axis 3 | singularity exec --bind $basedir/ $basedir/neurodock_latest.sif mrconvert - meanb0.nii
mri_synthstrip -i meanb0.nii -m new_brain_mask.nii

#csf mask, csf-excluded smoothing, rician bias correction, and model fitting with pydesigner
cd $designerdir
mkdir -p $designerdir/metrics_qc/fitting
singularity exec --bind $basedir/ $basedir/neurodock_latest.sif pydesigner --resume -n -u -cd 2 -z -r --user_mask $designerdir/tmp/new_brain_mask.nii --verbose --noqc --nthreads 4 -o $designerdir/ $rawdwi.nii.gz
rm -rf $designerdir/tmp/

##calculate colormap from diffusion tensor
singularity exec --nv --bind $basedir $basedir/neurodock_latest.sif tensor2metric $designerdir/metrics/DT.nii -vector $designerdir/metrics/dti_V1.nii -modulate none -force

#fit NODDI model using the AMICO program
conda deactivate
source activate ~/.conda/envs/amico/
python3 $projectdir/amico_noddi.py $j

#fit SMI model using matlab
module load matlab/R2024a
matlab -sd $designerdir -batch "addpath('${basedir}/SMI'); nii = niftiread('dwi_preprocessed.nii'); dwi = abs(double(nii)); bval = load('dwi_preprocessed.bval'); dirs = load('dwi_preprocessed.bvec'); nii_mask = niftiread('brain_mask.nii'); sigma_nii = niftiread('noisemap.nii'); options.b = bval; options.beta = []; options.dirs = dirs; options.TE   = []; options.MergeDistance = 0.1; options.mask = logical(nii_mask); options.sigma = abs(sigma_nii); options.compartments = {'IAS','EAS'}; options.NoiseBias = 'Rician'; options.MLTraining.bounds = [0.05, 1, 1, 0.1, 0, 50, 50, 0.05; 0.95, 3, 3, 1.2, 0.5, 150, 120, 0.99]; [out] = SMI.fit(dwi,options); niftiwrite(out.kernel(:,:,:,1), 'metrics/smi_matlab_f.nii'); niftiwrite(out.kernel(:,:,:,2), 'metrics/smi_matlab_Da.nii'); niftiwrite(out.kernel(:,:,:,3), 'metrics/smi_matlab_DePar.nii'); niftiwrite(out.kernel(:,:,:,4), 'metrics/smi_matlab_DePerp.nii'); niftiwrite(out.kernel(:,:,:,6), 'metrics/smi_matlab_p2.nii');"

fslcpgeom $designerdir/dwi_preprocessed.nii $designerdir/metrics/smi_matlab_f.nii -d
fslcpgeom $designerdir/dwi_preprocessed.nii $designerdir/metrics/smi_matlab_Da.nii -d
fslcpgeom $designerdir/dwi_preprocessed.nii $designerdir/metrics/smi_matlab_DePar.nii -d
fslcpgeom $designerdir/dwi_preprocessed.nii $designerdir/metrics/smi_matlab_DePerp.nii -d
fslcpgeom $designerdir/dwi_preprocessed.nii $designerdir/metrics/smi_matlab_p2.nii -d