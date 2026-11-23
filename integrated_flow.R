# ANNUAL RESULTS REPORT ----
## CHECKS FLOW (cleaning + checks, CR and PR) ----

### Prep environment ----
source("scripts/prep_env.R")
### Cleaning ----
source("scripts/cr/cleaning/cr_cleaning.R")
source("scripts/mne/mne_cleaning.R")
source("scripts/pr/cleaning/pr_cleaning.R")
### Checks ----
source("scripts/cr/checks/cr_data_checks.R")
source("scripts/cr/checks/cr_data_checks_new.R")
source("scripts/cr/checks/cr_numbers_checks_reached.R")
source("scripts/cr/checks/cr_numbers_checks_targeted.R")
source("scripts/pr/checks/pr_data_checks.R")
source("scripts/pr/checks/pr_number_checks.R")
