# Prep env ----
source("scripts/prep_env.R")
today <- today()
folder_path <- paste0("data/output/cr/", Sys.Date(), "/")
dir.create(folder_path, recursive = TRUE, showWarnings = FALSE)

# CLEAN MNE TRACKER ----
# Load MnE tracker ----
# put it in another script
df <- read.xlsx(mne_approval, 
                sheet = sheet_mne, 
                startRow = 4,
                detectDates = TRUE, sep.names = " ")
diag_input(df, "MnE tracker")
trace_step(df, "MnE: input tracker")

## Column names ----
colnames(df) <- gsub("\\s+", "", colnames(df))

df <- df %>%
  rename(# LeadGRN = LeadgranteeGRN,
         Grantee = Granteeorganization,
         MEFocalPerson = `M&Efocalperson`)

## ARR report year filter ----
# df <- df %>%
#   filter(ARRreportyear == report_year) %>%
#   select(-c(Latesubmissionapproveddate,
#             Extendeddeadline, 
#             Folder, 
#             LeadFolder, 
#             Templatesaved, 
#             Templateshared, 
#             GMComments, 
#             MnEcommentsforGM, 
#             MEFocalPerson, 
#             Linktotemplate, 
#             Commentsontemplate, 
#             Supervisorsincharge )) %>%
#   arrange(Country, Typeofinvestment, LeadGRN, Leadgrantee)


# Filter ----
df %<>%
  filter(Typeofinvestment != "AF")
         
# df %<>%
#   filter(Reportingperiodupto > "2024-12-31")

# df %<>%
#   mutate(Activein2025 =
#            ifelse(Startdate <= "2025-12-31" &
#                     Currentenddate >= "2025-01-01", "Yes", "No"))

df %<>%
  mutate(ActiveStrategicPlan =
           ifelse(Startdate <= strategic_plan_end &
                    Currentenddate > strategic_plan_start, "Yes", "No"))

trace_step(df, "MnE: after removing AF programmes")
# saving csv
write.csv(df, "data/cleaned/MnE Report Tracker.csv", row.names = FALSE)

if (!isTRUE(getOption("arr.debug"))) rm(list = ls())
