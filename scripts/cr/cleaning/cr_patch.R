# CR patch: year-specific exclusions (set `cr_exclude_leadgrn` in config.yml)
source("scripts/prep_env.R")

library(magrittr)

df <- read.csv("data/cleaned/CR Combiner - For Analysis.csv", encoding = "UTF-8")

# patch ----
df %<>%
  filter(!is.na(LeadGRN), !LeadGRN %in% cr_exclude_leadgrn)

write.csv(df, "data/cleaned/CR Combiner - For Analysis.csv", row.names = FALSE)
