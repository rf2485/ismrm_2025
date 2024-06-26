import ants
import numpy as np
import os
import sys
from lib.designer_func_wrappers import *
from mrtrix3 import image

# subject=sys.argv[1]
study=sys.argv[1]
nii = ants.image_read(os.path.join(study, "working_rpg.nii"))
first_vol = ants.image_read(os.path.join(study, "first_volume_rpg.nii"))
ants_moco_params = ants.motion_correction(nii, fixed=first_vol, moreaccurate=2)
ants.image_write(ants_moco_params['motion_corrected'], os.path.join(study, "working_antsmoco.nii"))
dwi_header = image.Header(os.path.join(study, "dwi.mif"))
grad = dwi_header.keyval()['dw_scheme']
grad = [ line for line in grad ]
grad = [ [ float(f) for f in line ] for line in grad ]
grad = np.array(grad)
grad[:,-1] = grad[:,-1] / 1000
dirs = grad[:,:3]
dirs_rot = np.zeros_like(dirs)
for i in range(grad.shape[0]):
        antsaffine = ants_moco_params['motion_parameters'][i][0]
        aff = convert_ants_xform(antsaffine, i)
        diri = np.hstack((dirs[i,:],0))
        dirs_rot[i,:] = (aff @ diri.T)[:3]
np.savetxt(os.path.join(study, "working_antsmoco.bvec"), dirs_rot.T, delimiter=' ', fmt='%4.10f')