# Make a SYNTHETIC (fake) MnE reports tracker, for test runs.
#
#   Rscript developers/make_synthetic_mne_tracker.R
#   Rscript developers/make_synthetic_mne_tracker.R data/input/my_test_tracker.xlsx
#
# Why: the real tracker is confidential and the one of the new year may not exist yet. To test
# the whole flow (cleaning, checks, analysis) we need a file with the same layout. This script
# builds one from YOUR grants list (`grants_db.csv`), so that the programme numbers match the
# CR / PR data and the filters have something to do. Everything else is made up.
#
# What it makes (see docs/mne-tracker.md):
#   * sheet `Results_Reports_Auto` (the name in `sheet_mne`), 6 empty rows, the header in row 7
#   * the same 32 column names as the 2025 tracker, so the scripts read it exactly as the real one
#   * one row for each Lead or Single grant that is active in the report year, plus a few rows of
#     the year before, plus 3 fake AF rows (the cleaning removes AF)
#   * GM Status: about 80% Completed, 12% Waived, 8% "Not yet Received" (to test the filter)
#
# SAFETY
#   * It NEVER overwrites a file. Delete the old file yourself if you want to make a new one.
#   * Cell A1 of the file says that it is synthetic.
#   * NEVER use it for a real run: it makes (almost) every programme "approved", so the checks
#     would hide problems. The folder data/input/ is not committed to Git.

suppressMessages({library(openxlsx)})

cfg <- yaml::read_yaml("config.yml")
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1] else file.path("data", "input", "mne_tracker_SYNTHETIC.xlsx")
if (file.exists(out)) stop("Refusing to overwrite an existing file: ", out, "\nDelete it first if you really want a new one.", call. = FALSE)

y    <- as.integer(cfg$report_year)
gpath <- file.path("data", "input", cfg$grants_db)
if (!file.exists(gpath)) stop("grants list not found: ", gpath, call. = FALSE)
g <- utils::read.csv(gpath, encoding = "UTF-8", stringsAsFactors = FALSE)

act_now  <- paste0("Activein", y)
act_prev <- paste0("Activein", y - 1)
if (!all(c(act_now, act_prev) %in% names(g))) stop("grants list has no ", act_now, " / ", act_prev, " column", call. = FALSE)

g <- g[!is.na(g$ProgrammeID) & !is.na(g$GMGRN) & g$Reportingrole %in% c("Lead", "Single"), ]
now  <- g[g[[act_now]] == "Yes", ]
prev <- g[g[[act_now]] != "Yes" & g[[act_prev]] == "Yes", ]
prev <- prev[seq_len(min(nrow(prev), max(1, round(0.15 * nrow(now))))), ]
if (nrow(now) == 0) stop("no Lead or Single grant is active in ", y, ": nothing to build the tracker from", call. = FALSE)

set.seed(y)   # the same input gives the same fake tracker
rows <- rbind(transform(now, .year = y), transform(prev, .year = y - 1))
n <- nrow(rows)
status <- sample(c("Completed", "Waived", "Not yet Received"), n, replace = TRUE, prob = c(0.80, 0.12, 0.08))
if (n >= 5) status[1:3] <- c("Completed", "Waived", "Not yet Received")   # every status is present at least once

as_date <- function(x) as.Date(x)
tracker <- data.frame(
  `Report Unique ID`      = paste0(rows$GMGRN, "-"),
  `GM GRN`                = rows$GMGRN,
  `Country`               = rows$Country,
  `Type of investment`    = rows$Typeofinvestment,
  `Programme ID`          = rows$ProgrammeID,
  `Grantee organization`  = rows$Granteeorganization,
  `Grant name (AF only)`  = NA_character_,
  `Start date`            = as_date(rows$Startdate),
  `Current end date`      = as_date(rows$Currentenddate),
  `Reporting role`        = rows$Reportingrole,
  `Processing status`     = ifelse(rows$.year == y, "Active", "Closed"),
  `Report Type`           = "Results",
  `Report Frequency`      = ifelse(rows$.year == y, "Annual", "Final"),
  `Report Due Date`       = as.Date(paste0(rows$.year + 1, "-03-31")),
  `Year`                  = rows$.year,
  `Folder`                = NA_character_,
  `Lead Folder`           = NA_character_,
  `GM Status`             = status,
  `GM Comment`            = NA_character_,
  `PM`                    = NA_character_,
  `M&E`                   = NA_character_,
  `Intern lead`           = NA_character_,
  `Responsible GM`        = NA_character_,
  `Sent to Programme`     = NA_character_,
  `Count`                 = 1,
  `Keep`                  = "Keep",
  `QA_Type`               = sample(c("Regular", "Quick"), n, replace = TRUE, prob = c(0.7, 0.3)),
  `ActiveinYEAR`          = "Yes",
  `Ed lead`               = NA_character_,
  `M&E lead`              = NA_character_,
  `M&E focal person`      = NA_character_,
  `M&E Status (Auto)`     = ifelse(status == "Not yet Received", "Not started", "Final approved"),
  check.names = FALSE, stringsAsFactors = FALSE)
names(tracker)[names(tracker) == "ActiveinYEAR"] <- act_now

# three fake AF rows: the cleaning must remove them
af <- tracker[rep(1, 3), ]
af[] <- lapply(af, function(x) if (is.character(x)) NA_character_ else x)
af$`Report Unique ID` <- paste0("00-AF-SYNTHETIC-0", 1:3, "-"); af$`GM GRN` <- paste0("00-AF-SYNTHETIC-0", 1:3)
af$`Type of investment` <- "AF"; af$`Programme ID` <- paste0("AF-SYNTHETIC-0", 1:3)
af$`Grant name (AF only)` <- paste("Synthetic AF grant", 1:3); af$Country <- "Testland"
af$`GM Status` <- "Completed"; af$`Reporting role` <- "Single"; af$`Processing status` <- "Active"; af$Year <- y
af$`Start date` <- as.Date(paste0(y - 1, "-01-01")); af$`Current end date` <- as.Date(paste0(y + 1, "-12-31"))
tracker <- rbind(tracker, af)

wb <- createWorkbook()
sheet <- cfg$sheet_mne
addWorksheet(wb, sheet)
writeData(wb, sheet, "SYNTHETIC TEST TRACKER: fake data made by developers/make_synthetic_mne_tracker.R. NOT the real tracker. Never use it for a real run.",
          startRow = 1, startCol = 1, colNames = FALSE)
writeData(wb, sheet, tracker, startRow = 7, headerStyle = createStyle(textDecoration = "bold"))   # rows 2-6 stay empty
dateStyle <- createStyle(numFmt = "yyyy-mm-dd")
for (col in c("Start date", "Current end date", "Report Due Date"))
  addStyle(wb, sheet, dateStyle, rows = 8:(7 + nrow(tracker)), cols = which(names(tracker) == col), gridExpand = TRUE)
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
saveWorkbook(wb, out)

cat("Synthetic tracker written:", out, "\n")
cat(sprintf("  %d rows: %d active in %d, %d of %d, %d fake AF rows\n", nrow(tracker), nrow(now), y, nrow(prev), y - 1, 3))
print(table(tracker$`GM Status`))
cat("\nTo use it: set  mne_approval: \"", basename(out), "\"  in config.yml (and keep sheet_mne: \"", sheet, "\").\n", sep = "")
cat("Then run  Rscript scripts/check_setup.R  to see that both readers find the header.\n")
