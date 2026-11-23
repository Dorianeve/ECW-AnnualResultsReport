# Setup check ("doctor") ----
# Looks at the settings, the input files and the code BEFORE a run, and says what will break and
# why. Run it first when something is wrong, when a new year starts, or when a parameter or a
# column is added:
#
#   Rscript scripts/check_setup.R
#
# Every row has a status: OK, WARN (probably wrong, the run may still work) or FAIL (the run will
# stop). Only names, dates and counts are looked at: no data rows are read.

# Settings that every run needs (the names used in config.yml)
CONFIG_REQUIRED <- c("combiner_cr", "combiner_pr", "grants_db", "mne_approval", "sheet_mne", "codes",
                     "report_year", "previous_report_year", "report_year_number", "source_cr", "source_pr",
                     "annual", "cumulative", "past_annual", "past_cumulative", "ex_com_approval_date_cutoff",
                     "strategic_plan_start", "strategic_plan_end", "achieved_as_rw", "cr_exclude_leadgrn", "pr_exclude_leadgrn")

# Columns the scripts use, written as they are AFTER the cleaning removes the spaces of the names
COLUMNS_REQUIRED <- list(
  cr = c("ProgrammeID", "LeadGRN", "GMGRN", "Typeofinvestment", "Country", "Granteeorganization",
         "Typeofeducation", "Levelofeducation", "Typeofbeneficiary", "Status", "Gender", "Typeofreporting",
         "Sourceofdata", "Covid19relateddata", "Covid19relatedgrant", "Indicator", "Commentsandcontext",
         "Filename", "GRID", "Exercise", "Startdate", "Currentenddate", "Number", "ActiveStrategicPlan"),
  pr = c("ProgrammeID", "LeadGRN", "GMGRN", "Typeofinvestment", "Country", "Granteeorganization", "CurrentEndDate",
         "Startdate", "IndicatorAdmin", "AnalysisCode", "UnitOfMeasurement", "ProgramSpecificIndicator", "Indicator",
         "IndicatorFromLibrary", "Exercise", "Covid19related", "Value", "SourceOfData", "ReportingWindow",
         "Gender", "ActiveStrategicPlan"),
  grants = c("ProgrammeID", "GMGRN", "Typeofinvestment", "Reportingrole", "Startdate", "Currentenddate",
             "Excomapprovaldate", "ActiveStrategicPlan"),
  mne_cleaning = c("Typeofinvestment", "Startdate", "Currentenddate", "Granteeorganization", "M&Efocalperson"),
  mne_checks = c("Programme ID", "GM Status"))

# Columns that the cleaning scripts CREATE (or rename to). If an input already has them, it was
# cleaned before (for example last year's ARR output was used as the "previous combiner" in the
# Combiner) and the cleaning stops with "Names must be unique".
COLUMNS_CREATED <- list(
  cr = c("Grantee", "date", "yearstart", "yearend", "exercice"),
  pr = c("Grantee", "unit", "code", "indicatoradmin", "Sourceofdata", "Reportingwindow", "exercice", "c19", "Total",
         "revised_unit", "unit2", "yearend", "yearstart", "monthstart", "monthend", "daystart", "dayend",
         "concat", "Priority", "level_code", "RW_number"))

setup_row <- function(check, status, detail = "", hint = "") {
  data.frame(check = check, status = status, detail = detail, hint = hint, stringsAsFactors = FALSE)
}

#' Years written into the scripts (so a new year that the code does not know yet is found)
script_years <- function(root = ".") {
  code_lines <- function(file) {
    x <- readLines(file, warn = FALSE)
    x[!grepl("^[[:space:]]*#", x)]
  }
  years <- function(files, pattern, group) {
    x <- unlist(lapply(files[file.exists(files)], code_lines))
    m <- unlist(regmatches(x, gregexpr(pattern, x)))
    sort(unique(as.integer(sub(group, "\\1", m))))
  }
  p <- function(...) file.path(root, ...)
  checks <- list.files(p("scripts"), pattern = "[.]R$", recursive = TRUE, full.names = TRUE)
  checks <- checks[grepl("/checks/", checks)]
  list(cr_source  = years(p("scripts", "cr", "cleaning", "cr_cleaning.R"), "\"CR[0-9]{2}\"", ".*CR([0-9]{2}).*"),
       pr_source  = years(p("scripts", "pr", "cleaning", "pr_cleaning.R"), "\"PR[0-9]{2}\"", ".*PR([0-9]{2}).*"),
       exercise   = years(c(p("scripts", "cr", "cleaning", "cr_cleaning.R"), p("scripts", "pr", "cleaning", "pr_cleaning.R")),
                          "\"[0-9]{2} (annual|cumulative)\"", "\"([0-9]{2}) .*"),
       active_in  = years(checks, "Activein20[0-9]{2}", "Activein(20[0-9]{2})"))
}

#' Run the setup check
#'
#' @param root The project folder (the folder with `config.yml`).
#' @return A data frame (check, status, detail, hint), invisibly. Printing is done by
#'   [print_setup_check()].
setup_check <- function(root = ".") {
  p <- function(...) file.path(root, ...)
  out <- list()
  add <- function(...) out[[length(out) + 1]] <<- setup_row(...)
  norm <- function(x) gsub("[[:space:]]+", "", x)
  header <- function(path, sheet = NULL, skip = 0) {
    names(readxl::read_excel(path, sheet = sheet %||% 1, skip = skip, n_max = 0))
  }

  # 1. settings ----
  if (!file.exists(p("config.yml"))) {
    add("config.yml", "FAIL", "config.yml not found", "Copy config.example.yml to config.yml and fill it in")
    return(invisible(do.call(rbind, out)))
  }
  cfg <- tryCatch(yaml::read_yaml(p("config.yml")), error = function(e) e)
  if (inherits(cfg, "error")) {
    add("config.yml", "FAIL", paste("cannot be read:", conditionMessage(cfg)), "Each line must be `name: value`; check quotes and spaces")
    return(invisible(do.call(rbind, out)))
  }
  missing <- setdiff(CONFIG_REQUIRED, names(cfg))
  add("config.yml: required settings", if (length(missing)) "FAIL" else "OK",
      if (length(missing)) paste("missing:", paste(missing, collapse = ", ")) else "all present",
      if (length(missing)) "Compare with config.example.yml: a new setting must be added to both files" else "")
  extra <- setdiff(names(cfg), c(names(yaml::read_yaml(p("config.example.yml"))), CONFIG_REQUIRED))
  if (file.exists(p("config.example.yml")) && length(extra))
    add("config.yml: unknown settings", "WARN", paste(extra, collapse = ", "),
        "A typo in a setting name is silently ignored. Check the spelling or add it to config.example.yml")
  if (length(missing)) return(invisible(do.call(rbind, out)))

  # 2. the year parameters agree with each other ----
  y  <- suppressWarnings(as.integer(cfg$report_year))
  if (is.na(y)) {
    add("report_year", "FAIL", paste("not a year:", cfg$report_year), "Write the year with four digits, for example \"2026\"")
  } else {
    yy <- y %% 100
    expected <- list(report_year_number = y, previous_report_year = y - 1, source_cr = paste0("CR", yy),
                     source_pr = paste0("PR", yy), annual = 2 * yy - 40, cumulative = 2 * yy - 39,
                     past_annual = 2 * yy - 42, past_cumulative = 2 * yy - 41)
    bad <- names(expected)[!mapply(function(k, v) identical(as.character(cfg[[k]]), as.character(v)), names(expected), expected)]
    add("yearly settings agree with report_year", if (length(bad)) "WARN" else "OK",
        if (length(bad)) paste0(paste(sprintf("%s is %s (expected %s)", bad, vapply(bad, function(k) as.character(cfg[[k]]), ""),
                                              vapply(bad, function(k) as.character(expected[[k]]), "")), collapse = "; ")) else
          sprintf("year %s: annual %s, cumulative %s", y, cfg$annual, cfg$cumulative),
        if (length(bad)) "Change them if this is a mistake. annual = 2 x (last two digits) - 40; cumulative = annual + 1" else "")

    # 3. years that are written into the scripts ----
    sy <- script_years(root)
    for (what in list(list("cr_source", "CR source labels in cr_cleaning.R", yy),
                      list("pr_source", "PR source labels in pr_cleaning.R", yy),
                      list("exercise", "Exercise encoding in cr_cleaning.R and pr_cleaning.R", yy))) {
      have <- sy[[what[[1]]]]
      ok <- !length(have) || what[[3]] <= max(have)
      add(paste("scripts know the year:", what[[2]]), if (ok) "OK" else "FAIL",
          if (!length(have)) "no year is written in the script: it is read from the settings" else
            sprintf("the scripts go up to 20%s, the report year is %s", max(have), y),
          if (ok) "" else "Add the new year to the case_when() list of that script (copy the last line and change the number)")
    }
    if (length(sy$active_in)) {
      ok <- y %in% sy$active_in
      add("scripts know the year: Activein columns in the check scripts", if (ok) "OK" else "WARN",
          paste("hard-coded:", paste0("Activein", sy$active_in, collapse = ", ")),
          if (ok) "" else paste0("The check scripts name these columns one by one. Add Activein", y, " where the others are listed (search for \"Activein", sy$active_in[1], "\")"))
    }
  }

  # 4. input files ----
  in_dir <- p("data", "input")
  mne <- cfg$mne_approval
  if (!grepl("^([A-Za-z]:|/|~|[\\][\\])", mne)) mne <- file.path(in_dir, mne)
  files <- list(
    list("cr",     file.path(in_dir, cfg$combiner_cr), "Run the Combiner (it copies the file here), or copy cr_clean.xlsx by hand"),
    list("pr",     file.path(in_dir, cfg$combiner_pr), "Run the Combiner (it copies the file here), or copy pr_clean.xlsx by hand"),
    list("grants", file.path(in_dir, cfg$grants_db),   "Run the Combiner (it copies grants_db.csv here), or copy it by hand"),
    list("mne",    mne,                                 "Put the MnE reports tracker there, or set mne_approval in config.yml to its full path"),
    list("log",    file.path(in_dir, "log_decisions", "log_decisions.xlsx"), "Copy templates/log_decisions.xlsx and fill it in"),
    list("prio",   file.path(in_dir, "patch", "priority_grn_codes.xlsx"),    "Copy templates/priority_grn_codes.xlsx and fill it in"),
    list("units",  file.path(in_dir, "patch", "patch_units.csv"),            "Copy templates/patch_units.csv and fill it in"),
    list("codes",  file.path(in_dir, "analysis_codes", cfg$codes),           "The file should be in the repository: check the name in config.yml"))
  found <- list()
  for (f in files) {
    ok <- file.exists(f[[2]])
    found[[f[[1]]]] <- ok
    add(paste("input file:", basename(f[[2]])), if (ok) "OK" else "FAIL",
        if (ok) sprintf("%s, modified %s", format(structure(file.size(f[[2]]), class = "object_size"), units = "auto"),
                        format(file.mtime(f[[2]]), "%Y-%m-%d %H:%M")) else paste("not found:", f[[2]]), if (ok) "" else f[[3]])
  }

  # 5. columns the scripts need ----
  need_cols <- function(label, have, required, hint, status_if_missing = "FAIL") {
    miss <- setdiff(required, have)
    add(paste("columns:", label), if (length(miss)) status_if_missing else "OK",
        if (length(miss)) paste("missing:", paste(miss, collapse = ", ")) else sprintf("%d columns checked", length(required)),
        if (length(miss)) hint else "")
  }
  try_cols <- function(label, expr, required, hint, flow = NULL) {
    have <- tryCatch(expr, error = function(e) e)
    if (inherits(have, "error")) { add(paste("columns:", label), "FAIL", paste("cannot be read:", conditionMessage(have)), hint); return(invisible()) }
    need_cols(label, have, required, hint)
    if (!is.null(flow)) {
      dup <- unique(have[duplicated(have)])
      add(paste("columns:", label, "- no duplicate names"), if (length(dup)) "FAIL" else "OK",
          if (length(dup)) paste("duplicated:", paste(dup, collapse = ", ")) else "", if (length(dup)) "Two columns have the same name once the spaces are removed" else "")
      created <- intersect(have, COLUMNS_CREATED[[flow]])
      add(paste("columns:", label, "- not cleaned before"), if (length(created)) "FAIL" else "OK",
          if (length(created)) paste("already present:", paste(created, collapse = ", ")) else "",
          if (length(created)) paste0("The file already holds columns that the cleaning creates, so it comes from an earlier ARR cleaning. ",
                                       "In the Combiner, `inputs: previous_", flow, "_combiner` must be the Combiner's own output of last year, not the ARR cleaned file") else "")
    }
  }
  if (isTRUE(found$cr)) try_cols(cfg$combiner_cr, norm(header(file.path(in_dir, cfg$combiner_cr))), COLUMNS_REQUIRED$cr,
                                 "The Combiner output changed. A renamed column needs a change in the cleaning script", flow = "cr")
  if (isTRUE(found$pr)) try_cols(cfg$combiner_pr, norm(header(file.path(in_dir, cfg$combiner_pr))), COLUMNS_REQUIRED$pr,
                                 "The Combiner output changed. A renamed column needs a change in the cleaning script", flow = "pr")
  if (isTRUE(found$grants)) {
    act <- unique(c(if (!is.na(y)) active_year_cols(y), if (exists("sy") && length(sy$active_in)) paste0("Activein", sy$active_in)))
    try_cols(cfg$grants_db, names(utils::read.csv(file.path(in_dir, cfg$grants_db), nrows = 1, encoding = "UTF-8")),
             c(COLUMNS_REQUIRED$grants, act),
             "ActiveinYYYY columns come from the Combiner (`reporting: active_years`): they must include the last 3 years up to the report year")
  }
  if (isTRUE(found$mne)) {
    sheets <- tryCatch(readxl::excel_sheets(mne), error = function(e) character())
    if (!cfg$sheet_mne %in% sheets) {
      add("MnE tracker: sheet", "FAIL", sprintf("sheet '%s' not found (found: %s)", cfg$sheet_mne, paste(sheets, collapse = ", ")),
          "Set sheet_mne in config.yml")
    } else {
      try_cols("MnE tracker, header as read by mne_cleaning.R (row 4)",
               norm(names(openxlsx::read.xlsx(mne, sheet = cfg$sheet_mne, startRow = 4, sep.names = " "))),
               COLUMNS_REQUIRED$mne_cleaning, "The layout of the tracker changed: the header must be in row 4")
      try_cols("MnE tracker, header as read by the check scripts (skip = 6)",
               header(mne, sheet = cfg$sheet_mne, skip = 6), COLUMNS_REQUIRED$mne_checks,
               "The layout of the tracker changed: the checks read the header after skipping 6 rows (`skip = 6`)")
    }
  }
  if (isTRUE(found$log)) {
    lp <- file.path(in_dir, "log_decisions", "log_decisions.xlsx"); sh <- readxl::excel_sheets(lp)
    for (s in c("cr", "pr")) {
      if (!s %in% sh) { add(paste("log_decisions: sheet", s), "FAIL", "sheet not found", "Copy the sheets from templates/log_decisions.xlsx"); next }
      try_cols(paste("log_decisions, sheet", s), header(lp, s), c("ProgrammeID", "LeadGRN", "Issue"),
               "The names of the columns must stay as in the template; `Issue` is copied from the check")
    }
  }
  if (isTRUE(found$prio)) {
    pp <- file.path(in_dir, "patch", "priority_grn_codes.xlsx"); sh <- readxl::excel_sheets(pp)
    if (!all(c("Codes", "LeadGRN") %in% sh)) add("priority_grn_codes: sheets", "FAIL", paste("found:", paste(sh, collapse = ", ")), "Needs the sheets Codes and LeadGRN")
    else {
      try_cols("priority_grn_codes, sheet Codes", header(pp, "Codes"), c("Analysis code", "Priority", "Level"), "See templates/priority_grn_codes.xlsx")
      try_cols("priority_grn_codes, sheet LeadGRN", header(pp, "LeadGRN"), "Lead Grantee GRN", "See templates/priority_grn_codes.xlsx")
    }
  }
  if (isTRUE(found$units))
    try_cols("patch_units.csv", names(utils::read.csv(file.path(in_dir, "patch", "patch_units.csv"), nrows = 1, encoding = "UTF-8")),
             c("LeadGRN", "code", "Exercise", "Unit"), "See templates/patch_units.csv")
  if (isTRUE(found$codes)) {
    sh <- readxl::excel_sheets(file.path(in_dir, "analysis_codes", cfg$codes))
    add("analysis_codes: sheets", if (all(c("in", "old") %in% sh)) "OK" else "FAIL", paste("found:", paste(sh, collapse = ", ")),
        "pr_data_checks.R reads the sheets `in` and `old`")
  }

  # 6. can the outputs be written? ----
  for (d in c("data/cleaned", "data/output")) {
    dir.create(p(d), recursive = TRUE, showWarnings = FALSE)
    ok <- file.access(p(d), 2) == 0
    add(paste("folder can be written:", d), if (ok) "OK" else "FAIL", p(d), if (ok) "" else "Check the permissions of the folder")
  }

  invisible(do.call(rbind, out))
}

#' Print the result of [setup_check()] as plain text
print_setup_check <- function(res) {
  sym <- c(OK = "[ OK ]", WARN = "[WARN]", FAIL = "[FAIL]")
  for (i in seq_len(nrow(res))) {
    cat(sym[[res$status[i]]], " ", res$check[i], if (nzchar(res$detail[i])) paste0(" - ", res$detail[i]), "\n", sep = "")
    if (res$status[i] != "OK" && nzchar(res$hint[i])) cat("       -> ", res$hint[i], "\n", sep = "")
  }
  cat(sprintf("\n%d OK, %d WARN, %d FAIL\n", sum(res$status == "OK"), sum(res$status == "WARN"), sum(res$status == "FAIL")))
  invisible(res)
}
