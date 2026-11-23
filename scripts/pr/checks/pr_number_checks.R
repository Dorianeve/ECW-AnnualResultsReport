# PR FLOW - Number checks ----


# Prep env ----
source("scripts/prep_env.R")
today <- today()
folder_path <- paste0("data/output/pr/", Sys.Date(), "/")
dir.create(folder_path, recursive = TRUE, showWarnings = FALSE)
wb <- createWorkbook()

# PR CHECKS ----
## Load ---
df <- read.csv("data/cleaned/PR Combiner - For Checks.csv", encoding = "UTF-8")
trace_step(df, "PR number checks: cleaned file read")

## MnE /GMS import for filtering -----
mne <- read_xlsx(mne_approval,
                 sheet = sheet_mne,
                 skip = 6)

gms <- read.csv(paste0("data/input/grants_db.csv"), encoding = "UTF-8")

gms %<>%
  filter(ActiveStrategicPlan == "Yes")

mne %<>%
  filter(`GM Status` == "Completed" | `GM Status` == "Waived")

df %<>%
  filter(ProgrammeID %in% mne$`Programme ID`)
trace_step(df, "PR number checks: after keeping programmes in the MnE tracker (Completed/Waived)")

df %<>%
  filter(ProgrammeID %in% gms$ProgrammeID)
trace_step(df, "PR number checks: after keeping programmes in the active strategic plan (GMS)")

## Filter annual / cumulative ----
df %<>% 
  filter(exercice == annual | exercice == cumulative)

# # adding here the check for analysis codes as it is not possible in 2023 to do it before filtering
# list_codes <- read_excel(paste0("data/input/analysis_codes/", codes), sheet = "in")
# 
# list_codes <- list_codes %>%
#   mutate(codes = if_else(grepl("n2cwd", codes, ignore.case = TRUE), 
#                          "n2_cwd", codes))
# list_codes <- list_codes %>%
#   mutate(codes = if_else(grepl("t2a", codes), 
#                          "t2_a", codes))
# list_codes <- list_codes %>%
#   mutate(codes = if_else(grepl("t6a", codes), 
#                          "t6_a", codes))
# list_codes <- list_codes %>%
#   mutate(codes = if_else(grepl("t6c", codes), 
#                          "t6_c", codes))
# 
# list_codes <- tolower(list_codes$codes)

## Filter priority codes and LeadGRN----
# From here only priority codes and LeadGRN are under checks
# Load priority list
priority_codes <- read.xlsx("data/input/patch/priority_grn_codes.xlsx",
                            sheet = "Codes")
priority_leadGRN <- read.xlsx("data/input/patch/priority_grn_codes.xlsx",
                              sheet = "LeadGRN")

priority_codes %<>% select(Analysis.code, Priority, Level)
priority_codes %<>% 
  rename(code = Analysis.code,
         level_code = Level) %>%
  mutate(code = trimws(tolower(code)))

df %<>% 
  left_join(priority_codes, by = "code")

# Filter priority
priority_codes %<>%
  filter(Priority == 1)

priority_leadGRN %<>% 
  mutate(LeadGRN = trimws(Lead.Grantee.GRN))

# df %<>%
#   filter(LeadGRN %in% priority_leadGRN$LeadGRN)

df %<>%
  filter(ActiveStrategicPlan == "Yes")

df %<>%
  filter(code %in% priority_codes$code)

# Computed vs Imputed Totals ----
## Annual ----
### Filtering ----

df1 <- df %>%
  filter(exercice == annual & unit == "Number #")

annual_totals <- df1 %>%
  group_by(ProgrammeID, LeadGRN, Reportingwindow, code, Gender) %>%
  summarise(Total = sum(Total, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = Gender, values_from = Total) %>%
  mutate(across(c(Female, Male, Total), ~ tidyr::replace_na(., 0))) %>%
  mutate(
    ComputedTotal = Female + Male,
    Consistent = Total == ComputedTotal,
    ID = paste0(LeadGRN, "___", code)
  )


rm(df1)

## Cumulative ----
### Filtering ----

df1 <- df %>%
  filter(exercice == cumulative & unit == "Number #")

cumulative_totals <- df1 %>%
  group_by(ProgrammeID, LeadGRN, Reportingwindow, code, Gender) %>%
  summarise(Total = sum(Total, na.rm = TRUE)) %>%
  pivot_wider(names_from = Gender, values_from = Total) %>%
  mutate(across(c(Female, Male, Total), ~ tidyr::replace_na(., 0))) %>%
  mutate(ComputedTotal = Female + Male,
         Consistent = Total == ComputedTotal,
         ID = paste0(LeadGRN, "___", code))


rm(df1)

## Summary ----

annual_totals_summary <- annual_totals %>%
  filter(ComputedTotal != 0 & Consistent != TRUE) %>%
  mutate(ID = "Annual")

cumulative_totals_summary <- cumulative_totals %>%
  filter(ComputedTotal != 0 & Consistent != TRUE) %>%
  mutate(ID = "Cumulative")

totals_summary <- rbind(annual_totals_summary, cumulative_totals_summary)

# Reporting windows ----
## Filtering ----

df1 <- df %>%
  filter(exercice == cumulative) %>%
  filter(grepl("cumulative", Exercise, ignore.case = TRUE) & unit == "Number #") %>%
  mutate(extracted_chars = substr(Exercise, 4, 5),
         RW = trimws(paste(extracted_chars, Reportingwindow))) %>%
  arrange(RW)

sequential <- df1 %>%
  filter(Gender == "Total" &
           !grepl("achieved", RW, ignore.case = TRUE)) %>%
  group_by(ProgrammeID, LeadGRN, code, RW) %>%
  summarise(Total = sum(Total, na.rm = TRUE), .groups = "drop") %>%
  mutate(Total = ifelse(Total == 0, NA, Total)) %>%  # restore NA for zero-sum groups
  pivot_wider(names_from = RW, values_from = Total) %>%
  select(-contains("Revised"), -contains("Target"), -contains("Baseline"))

# Get the sorted columns
sorted_columns <- sort(colnames(sequential)[grepl("rw", colnames(sequential), ignore.case = TRUE)])

# Get the remaining columns that do not match "rw"
remaining_columns <- setdiff(colnames(sequential), sorted_columns)

# Combine the sorted columns and the remaining columns
all_columns <- c(remaining_columns, sorted_columns)

# Reorder the data frame
sequential <- sequential[, all_columns, drop = FALSE]

sequential <- sequential %>%
  rowwise() %>%
  mutate(non_na_counts = sum(!is.na(across(4:last_col()))))

rw_check <- sequential %>%
  filter(non_na_counts > 1) %>%
  select(-non_na_counts)

# Function to check if each value is greater than or equal to the value in the previous column and append a flag column
check_non_na_order <- function(df) {
  # Explicitly select only RW columns in correct order
  rw_cols <- grep("RW", names(df), value = TRUE)
  rw_cols <- rw_cols[order(rw_cols)]  # ensure RW1, RW2, RW3... order
  
  df_sub <- df[, rw_cols]
  
  is_ordered <- function(row) {
    row <- row[!is.na(row)]
    any(diff(row) < 0)
  }
  
  order_check <- apply(df_sub, 1, is_ordered)
  df$Flag <- order_check
  return(df)
}


rw_check <- check_non_na_order(rw_check)

rw_check_summary <- rw_check %>%
  mutate(Flag = ifelse(Flag == TRUE, "Discrepancy", NA)) %>%
  filter(Flag == "Discrepancy")


# Summary Sheet ----
totals_checks_summary<- totals_summary %>%
  mutate(Issue = "Computed total not equal imputed total") %>%
  select(ProgrammeID, LeadGRN, code, Issue)

rw_check_summary <- rw_check_summary %>%
  mutate(Issue = "Latest Reporting Window smaller than previous ones") %>%
  select(ProgrammeID, LeadGRN, code, Issue)

summary <- rbind(totals_checks_summary, rw_check_summary)

# Output ----
#### Filter Log ----
log <- read.xlsx("data/input/log_decisions/log_decisions.xlsx", sheet = "pr")

summary %<>%
  mutate(Concat = paste0(ProgrammeID, LeadGRN, Issue))

log %<>%
  mutate(Concat = paste0(ProgrammeID, LeadGRN, Issue))

diag_decisions(summary, log, "PR number checks")
summary %<>%
  filter(!Concat %in% log$Concat)

# List of checks and their corresponding sheet names
checks_list <- list(
  "OverallSummary" = summary,
  "ComputedVSImputed" = totals_summary,
  "SequentialRW" = sequential,
  "RWCheck" = rw_check_summary
)

# Loop through each check object and add to the workbook
for (sheet_name in names(checks_list)) {
  addWorksheet(wb, sheet_name)
  writeData(wb, sheet_name, checks_list[[sheet_name]])
}

# Save the workbook
saveWorkbook(wb, paste0(folder_path, "Number checks.xlsx"), overwrite = TRUE)

if (!isTRUE(getOption("arr.debug"))) rm(list = ls())
