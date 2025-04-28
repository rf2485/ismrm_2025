source("1_data_preparation_wm.R")
library(tidyverse)

problem_subjs <- c( 'sub-CC510255', 'sub-CC620821', 'sub-CC510438', 'sub-CC621011', 
                    'sub-CC710551', 'sub-CC721292' )

dwi_over_55$additional_hads_depression[dwi_over_55$additional_hads_depression > 21] <- NA

design_matrix <- dwi_over_55 %>%
  filter(!participant_id %in% problem_subjs) %>%
  arrange(desc(SCD), participant_id) %>%
  mutate(EV1 = ifelse(SCD == 'Control', 1, 0),
         EV2 = ifelse(SCD == 'SCD', 1, 0),
         memory_centered = scale(homeint_storyrecall_d, scale = F)) %>%
  select(EV1, EV2, memory_centered) %>%
  replace(is.na(.), 0)

interaction_con <- rbind(c(1,-1,0,0),
                         c(-1,1,0,0),
                         c(0,0,1,-1), 
                         c(0,0,-1,1), 
                         c(0,0,1,1),
                         c(0,0,-1,-1),
                         c(0,0,1,0), 
                         c(0,0,-1,0),
                         c(0,0,0,1),
                         c(0,0,0,-1)
                         )
write.table(interaction_con, file = "tbss/stats/interaction_con.txt", sep = "\t",
            row.names = F, col.names = F)

#model 1: memory interaction with scd
memory_int_mat <- design_matrix %>% select(EV1:EV2, memory_centered) %>%
  mutate(EV3 = ifelse(EV1 == 1, memory_centered, 0),
         EV4 = ifelse(EV1 == 0, memory_centered, 0)) %>%
  select(-memory_centered) %>%
  select(order(colnames(.))) #order columns alphabetically

memory_int_mat <- unname(as.matrix(memory_int_mat))
write.table(memory_int_mat, file = "tbss/stats/memory_int_mat.txt", sep = "\t", 
            row.names = F, col.names = F)
