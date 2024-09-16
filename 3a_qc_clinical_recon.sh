basedir=/gpfs/data/lazarlab/CamCan995/
projectdir=$basedir/derivatives/designer_tbss/
t1dir=$projectdir/freesurfer/

export FREESURFER_HOME=/gpfs/share/apps/freesurfer/7.4.1/raw/freesurfer/
module load freesurfer/7.4.1
export SUBJECTS_DIR=$t1dir

subj_list=$(cut -f1 $projectdir/anat_over_55.tsv)
subj_list=($subj_list)

mkdir -p $t1dir/group_qc/
echo '<HTML><TITLE>recon</TITLE><BODY BGCOLOR="#aaaaff">' > $t1dir/group_qc/index.html

for subj in "${subj_list[@]}"; do
	freeview -v $t1dir/$subj/mri/T1.mgz $t1dir/$subj/mri/aparc+aseg.mgz:colormap=lut:opacity=0.2 -viewport 'x' -slice 102 128 128 -nocursor -screenshot $t1dir/group_qc/grota.png
	freeview -v $t1dir/$subj/mri/T1.mgz $t1dir/$subj/mri/aparc+aseg.mgz:colormap=lut:opacity=0.2 -viewport 'x' -slice 128 128 128 -nocursor -screenshot $t1dir/group_qc/grotb.png
	freeview -v $t1dir/$subj/mri/T1.mgz $t1dir/$subj/mri/aparc+aseg.mgz:colormap=lut:opacity=0.2 -viewport 'x' -slice 154 128 128 -nocursor -screenshot $t1dir/group_qc/grotc.png
	freeview -v $t1dir/$subj/mri/T1.mgz $t1dir/$subj/mri/aparc+aseg.mgz:colormap=lut:opacity=0.2 -viewport 'y' -slice 128 102 128 -nocursor -screenshot $t1dir/group_qc/grotd.png
	freeview -v $t1dir/$subj/mri/T1.mgz $t1dir/$subj/mri/aparc+aseg.mgz:colormap=lut:opacity=0.2 -viewport 'y' -slice 128 128 128 -nocursor -screenshot $t1dir/group_qc/grote.png
	freeview -v $t1dir/$subj/mri/T1.mgz $t1dir/$subj/mri/aparc+aseg.mgz:colormap=lut:opacity=0.2 -viewport 'y' -slice 128 154 128 -nocursor -screenshot $t1dir/group_qc/grotf.png
	freeview -v $t1dir/$subj/mri/T1.mgz $t1dir/$subj/mri/aparc+aseg.mgz:colormap=lut:opacity=0.2 -viewport 'z' -slice 128 128 102 -nocursor -screenshot $t1dir/group_qc/grotg.png
	freeview -v $t1dir/$subj/mri/T1.mgz $t1dir/$subj/mri/aparc+aseg.mgz:colormap=lut:opacity=0.2 -viewport 'z' -slice 128 128 128 -nocursor -screenshot $t1dir/group_qc/groth.png
	freeview -v $t1dir/$subj/mri/T1.mgz $t1dir/$subj/mri/aparc+aseg.mgz:colormap=lut:opacity=0.2 -viewport 'z' -slice 128 128 154 -nocursor -screenshot $t1dir/group_qc/groti.png
	cd $t1dir/group_qc/
	pngappend grota.png + grotb.png + grotc.png + grotd.png + grote.png + grotf.png + grotg.png + groth.png + groti.png $subj.png
	echo '<a href="'${subj}'.png"><img src="'${subj}'.png" WIDTH='1000' >' ${subj}'</a><br>' >> $t1dir/group_qc/index.html
done

echo '</BODY></HTML>' >> $t1dir/group_qc/index.html