source("1_data_preparation.R")

dwi_over_55$abs_motion_mean <- NA
dwi_over_55$rel_motion_mean <- NA
for (subj in dwi_over_55$participant_id) {
  ec_disp <- read_delim(file.path("dwi_processed", subj, "metrics_qc/eddy/ec_disp.txt"), delim = " ", col_names = F)
  dwi_over_55[dwi_over_55$participant_id==subj, "abs_motion_mean"] <- ec_disp %>% pull(var=1) %>% mean(.)
  dwi_over_55[dwi_over_55$participant_id==subj, "rel_motion_mean"] <- ec_disp %>% pull(var=2) %>% mean(.)
}
motion <- dwi_over_55 %>% select(participant_id, abs_motion_mean, rel_motion_mean) %>%
  filter(rel_motion_mean > 0.34 & abs_motion_mean > 2)
