# =============================================================================
# INGEST DATA FROM AIRTABLE
# Pulls the log of decisions from the configured Airtable base/table and merges it into
# data/input/log_decisions/log_decisions.xlsx. Needs `airtable: enabled: true` in
# config.yml (base_id, table_name) and AIRTABLE_TOKEN in .Renviron (see .Renviron.example).
# =============================================================================

source("scripts/prep_env.R")

if (!isTRUE(airtable$enabled)) {

  message("Airtable sync is disabled (set `airtable: enabled: true` in config.yml to turn it on).")

} else {

  token <- Sys.getenv("AIRTABLE_TOKEN")
  if (!nzchar(token))
    stop("AIRTABLE_TOKEN is not set. Copy .Renviron.example to .Renviron, fill in the token, and restart R.")

  base_id    <- airtable$base_id
  table_name <- airtable$table_name

  # --- Run -------------------------------------------------------------------
  message("Connecting to Airtable base: ", base_id, " / table: ", table_name)

  records <- fetch_airtable(token, base_id, table_name)
  df      <- airtable_records_to_df(records)

  message("Data ingested: ", nrow(df), " rows x ", ncol(df), " columns")
  print(head(df))

  # --- Ensure df has all columns defined in log_decisions.xlsx "log" sheet ---
  log_ref_cols <- names(openxlsx::read.xlsx(
    "data/input/log_decisions/log_decisions.xlsx", sheet = "log", rows = 1))

  missing_cols <- setdiff(log_ref_cols, names(df))
  if (length(missing_cols) > 0) {
    message("Adding missing columns (present in log sheet but not in Airtable): ",
            paste(missing_cols, collapse = ", "))
    df[missing_cols] <- NA_character_
  }

  df <- dplyr::mutate(df, dplyr::across(dplyr::everything(), as.character))


  if (!"For Carly.id" %in% colnames(df)) {
    df$`For Carly.id` <- NA
  }

  carly <- df %>%
    select(FLOW, ProgrammeID_text, LeadGRN, CheckType, AnalysisCode, Issue, `For Carly.id`) %>%
    rename(ProgrammeID = ProgrammeID_text) %>%
    filter(!is.na(`For Carly.id`))

  write.csv(carly, "data/input/log_decisions/for_carly.csv", row.names = FALSE)

  df %<>% select(FLOW, ProgrammeID_text, LeadGRN, AnalysisCode, Issue, Addressed, Ignore, Justification,
                 Responsible_text, LastModified)

  df %<>%
    rename(
      ProgrammeID = ProgrammeID_text,
      Responsible = Responsible_text)


  cr <- df %>%
    filter(FLOW == "CR" & Ignore == TRUE) %>%
    select(-c(FLOW, Ignore))

  pr <- df %>%
    filter(FLOW == "PR" & Ignore == TRUE) %>%
    select(-c(FLOW, Ignore))

  df %<>%
    filter(Addressed == TRUE)

  # --- Export to Excel (append to existing) ---------------------------------
  out_path <- file.path("data/input/log_decisions/log_decisions.xlsx")

  force_character <- function(df) dplyr::mutate(df, across(everything(), as.character))

  if (file.exists(out_path)) {

    read_sheet_safe <- function(path, sheet, template) {
      result <- openxlsx::read.xlsx(path, sheet = sheet)
      if (is.null(result)) return(force_character(template[0, ]))
      force_character(result)
    }

    existing_log <- read_sheet_safe(out_path, "log", df)
    existing_cr  <- read_sheet_safe(out_path, "cr",  cr)
    existing_pr  <- read_sheet_safe(out_path, "pr",  pr)

    log_out <- dplyr::distinct(dplyr::bind_rows(existing_log, force_character(df)))
    cr_out  <- dplyr::distinct(dplyr::bind_rows(existing_cr,  force_character(cr)))
    pr_out  <- dplyr::distinct(dplyr::bind_rows(existing_pr,  force_character(pr)))

    message("Appending to existing file: ",
            nrow(log_out) - nrow(existing_log), " new log rows, ",
            nrow(cr_out)  - nrow(existing_cr),  " new cr rows, ",
            nrow(pr_out)  - nrow(existing_pr),  " new pr rows.")

  } else {
    log_out <- force_character(df)
    cr_out  <- force_character(cr)
    pr_out  <- force_character(pr)
    message("No existing file found — creating new.")
  }

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "cr")
  openxlsx::addWorksheet(wb, "pr")
  openxlsx::addWorksheet(wb, "log")
  openxlsx::writeData(wb, sheet = "cr",  x = cr_out)
  openxlsx::writeData(wb, sheet = "pr",  x = pr_out)
  openxlsx::writeData(wb, sheet = "log", x = log_out)
  openxlsx::saveWorkbook(wb, out_path, overwrite = TRUE)

  message("Saved: ", out_path)
}

