# ==================================================================================================
# TO DO NEXT YEAR: THE MnE REPORTS TRACKER
# ==================================================================================================
# Who this is for: the data scientist (or AI assistant) who starts the next reporting cycle.
# How to use it:   read the notes below, then run   Rscript developers/todo_next_year.R
#                  It prints the checklist and runs a small self-test of the DRAFT reader (section 4).
#                  Nothing here is used by the flow yet: it is a starting point, not finished code.
#
# Plain-English background: docs/mne-tracker.md   (read it first)
# ==================================================================================================


# --------------------------------------------------------------------------------------------------
# 1. WHAT THE TRACKER IS, AND HOW THE CODE USES IT TODAY (a reminder)
# --------------------------------------------------------------------------------------------------
# The MnE reports tracker is an Excel file of Grants Management: one row for each report a grant
# has to send, with the status of its approval (column `GM Status`).
#
# The flow uses it ONLY to check approved programmes. It is read in SEVEN places:
#
#   scripts/mne/mne_cleaning.R             openxlsx::read.xlsx(startRow = 4); removes AF; adds
#                                          ActiveStrategicPlan; writes data/cleaned/MnE Report Tracker.csv
#   scripts/cr/checks/cr_data_checks.R           \
#   scripts/cr/checks/cr_data_checks_new.R        |  readxl::read_xlsx(skip = 6); keep
#   scripts/cr/checks/cr_numbers_checks_reached.R |  `GM Status` == "Completed" | "Waived";
#   scripts/cr/checks/cr_numbers_checks_targeted.R|  keep only CR / PR rows whose ProgrammeID is
#   scripts/pr/checks/pr_data_checks.R            |  in the tracker's `Programme ID`
#   scripts/pr/checks/pr_number_checks.R         /
#   (cr_data_checks_new.R and pr_data_checks.R ALSO read the cleaned csv: ProgrammeID + GMGRN)
#
# The ANALYSIS does not read the tracker.
# Settings: `mne_approval` (file) and `sheet_mne` (sheet) in config.yml.
# Needed columns: `Programme ID`, `GM Status`, `GM GRN`, `Type of investment`, `Start date`,
#                 `Current end date`, `Grantee organization`, `M&E focal person`.


# --------------------------------------------------------------------------------------------------
# 2. WHY IT NEEDS WORK EVERY YEAR
# --------------------------------------------------------------------------------------------------
# * The tracker changes: the name, the layout and the columns were different in earlier years
#   (the old config said "this file will change next year").
# * It is read in two different ways (row 4 and skip = 6). They only agree because the sheet has
#   empty rows above the header.
# * "Approved" is written as text inside six scripts: "Completed" and "Waived".
# * If the header or a column name changes, six scripts break in six places.


# --------------------------------------------------------------------------------------------------
# 3. THE PLAN (do it in this order)
# --------------------------------------------------------------------------------------------------
# [ ] 1. Put the new tracker in data/input/ (it is confidential: never commit it) and set
#        `mne_approval` / `sheet_mne` in config.yml. Run   Rscript scripts/check_setup.R
#        and read the two "MnE tracker" lines. Do not change code yet.
# [ ] 2. Open the file by eye. Write the answers here, in this file:
#            sheet name:                      ...
#            row of the header:               ...
#            column with the programme:       ...  (today: "Programme ID")
#            column with the grant:           ...  (today: "GM GRN")
#            column with the approval status: ...  (today: "GM Status")
#            values of that column:           ...  (today: Completed, Waived, Not yet Received)
# [ ] 3. Ask Grants Management: which statuses mean "approved" this year? What does "Waived" mean
#        for the checks? Should the ANALYSIS also be limited to approved programmes? (Today it is not.)
# [ ] 4. Make a BACKUP of the results with the old code (see docs/development.md, "How to test a
#        change"), using the synthetic tracker:  Rscript developers/make_synthetic_mne_tracker.R
# [ ] 5. Replace the seven readers by ONE function, in a new file R/utils/mne.R. Start from the
#        draft in section 4 below. Then the six check scripts need only:
#            mne <- read_mne_tracker(mne_approval, sheet_mne)
#            mne <- mne_approved(mne)
#        and mne_cleaning.R uses the same function, so that "row 4" and "skip = 6" disappear.
# [ ] 6. Move the text "Completed" / "Waived" and the column names to config.yml
#        (for example `mne_status_column`, `mne_approved_statuses`), and add them to
#        CONFIG_REQUIRED in R/utils/setup_check.R. Update COLUMNS_REQUIRED there too.
# [ ] 7. Keep the output of mne_cleaning.R: data/cleaned/MnE Report Tracker.csv must still have the
#        columns ProgrammeID and GMGRN (cr_data_checks_new.R and pr_data_checks.R read them).
# [ ] 8. Prove nothing else changed: run the flow again on the synthetic tracker and compare with the
#        backup:  Rscript scripts/compare_outputs.R <before> <after>   -> everything IDENTICAL.
# [ ] 9. Run on the NEW real tracker. Differences from the synthetic run are expected (different
#        approved programmes): check that they are only that.
# [ ] 10. Update docs/mne-tracker.md, the README (section 3 and the yearly checklist), and make the
#         synthetic generator (developers/make_synthetic_mne_tracker.R) copy the NEW layout.
#
# Rules for an AI assistant:
#   - Do not change the filters of the check scripts without a backup and compare_outputs.R.
#   - Never use the synthetic tracker for a real run: it hides problems.
#   - Do not print or commit the real tracker. It has real grant numbers.


# --------------------------------------------------------------------------------------------------
# 4. DRAFT CODE (not used by the flow yet)
# --------------------------------------------------------------------------------------------------

#' Read the MnE tracker and find the header row by itself
#'
#' Looks in the first `search_rows` rows for the row that holds ALL the `required` column names.
#' That row is the header. This works whatever the number of empty or title rows above it.
#'
#' @param path,sheet The tracker file and the sheet.
#' @param required Column names that must be in the header row.
#' @return A data frame (columns keep their original names, with the spaces).
read_mne_tracker <- function(path, sheet, required = c("Programme ID", "GM Status"), search_rows = 30) {
  raw <- suppressMessages(readxl::read_excel(path, sheet = sheet, col_names = FALSE, n_max = search_rows, col_types = "text"))
  has_all <- vapply(seq_len(nrow(raw)), function(i) all(required %in% trimws(as.character(unlist(raw[i, ])))), logical(1))
  if (!any(has_all)) {
    matches <- vapply(seq_len(nrow(raw)), function(i) sum(required %in% trimws(as.character(unlist(raw[i, ])))), integer(1))
    best <- which.max(matches)
    stop("MnE tracker: no row in the first ", search_rows, " rows has all of these columns: ", paste(required, collapse = ", "),
         ".\nThe closest row has ", max(matches), " of ", length(required), ": ",
         paste(stats::na.omit(trimws(as.character(unlist(raw[best, ])))), collapse = " | "), call. = FALSE)
  }
  suppressMessages(readxl::read_excel(path, sheet = sheet, skip = which(has_all)[1] - 1))
}

#' Keep the rows whose report is approved
mne_approved <- function(tracker, approved = c("Completed", "Waived"), status_column = "GM Status") {
  if (!status_column %in% names(tracker)) stop("MnE tracker has no column '", status_column, "'", call. = FALSE)
  tracker[tracker[[status_column]] %in% approved, , drop = FALSE]
}


# --------------------------------------------------------------------------------------------------
# 5. SELF-TEST (runs only when you run this file with Rscript; needs no data)
# --------------------------------------------------------------------------------------------------
if (sys.nframe() == 0) {
  cat("\nTO DO NEXT YEAR: the MnE tracker\n")
  cat("Read docs/mne-tracker.md, then follow the plan in section 3 of this file.\n\n")
  cat("Self-test of the draft reader read_mne_tracker():\n")
  suppressMessages(library(openxlsx))
  make <- function(file, header_row, status_name = "GM Status", banner = TRUE) {
    wb <- createWorkbook(); addWorksheet(wb, "Results_Reports_Auto")
    df <- setNames(data.frame(c("2026-FER-AAA-01", "2026-FER-BBB-01", "2026-MYR-CCC-P1"), c("Completed", "Waived", "Not yet Received")),
                   c("Programme ID", status_name))
    if (banner) writeData(wb, 1, "banner text", startRow = 1, colNames = FALSE)
    writeData(wb, 1, df, startRow = header_row); saveWorkbook(wb, file, overwrite = TRUE)
  }
  ok <- function(label, pass) cat(sprintf("  [%s] %s\n", if (pass) " OK " else "FAIL", label))
  f1 <- tempfile(fileext = ".xlsx"); make(f1, header_row = 7)                       # like the 2025 tracker
  f2 <- tempfile(fileext = ".xlsx"); make(f2, header_row = 3, banner = FALSE)       # header higher up, no banner
  f3 <- tempfile(fileext = ".xlsx"); make(f3, header_row = 7, status_name = "Approval")   # the status column was renamed
  t1 <- read_mne_tracker(f1, "Results_Reports_Auto"); ok("header on row 7 (like 2025) is found", nrow(t1) == 3)
  t2 <- read_mne_tracker(f2, "Results_Reports_Auto"); ok("header on row 3 is found", nrow(t2) == 3)
  ok("approved rows are Completed + Waived", nrow(mne_approved(t1)) == 2)
  err <- tryCatch(read_mne_tracker(f3, "Results_Reports_Auto"), error = function(e) conditionMessage(e))
  ok("a renamed status column gives a clear message", grepl("closest row has 1 of 2", err))
  cat("\nWhat the message says when a column was renamed:\n  ", gsub("\n", "\n  ", err), "\n", sep = "")
}
