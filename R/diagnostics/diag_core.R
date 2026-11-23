# Diagnostics: shared pieces ----
# One folder per run under data/output/diagnostics/<kind>/, with a report that a person (or an AI
# assistant) can read to see what changed since the last run. It is also written when a run fails.
# It contains NO data rows and NO credentials: only names, counts and the values of
# low-cardinality (category-like) columns. <kind> is "cleaning" or "checks".

DIAG <- list(max_levels = 60,       # columns with more distinct values are not profiled by value
             na_jump = 0.10,        # change in the share of empty cells that is reported
             rows_change = 0.10,    # relative change in a row count that is reported
             trace_min_rows = 5,    # smallest change (in rows) that is reported
             max_listed = 12)       # values listed in one finding

`%||%` <- function(a, b) if (is.null(a)) b else a

finding <- function(severity, area, item, detail) {
  data.frame(severity = severity, area = area, item = item, detail = detail, stringsAsFactors = FALSE)
}

no_findings <- function() finding("", "", "", "")[0, ]

#' Join a few values into one short text: "a, b, c ... (+4 more)"
short_list <- function(x, n = DIAG$max_listed) {
  x <- as.character(x)
  if (length(x) <= n) return(paste(x, collapse = ", "))
  paste0(paste(x[seq_len(n)], collapse = ", "), " ... (+", length(x) - n, " more)")
}

#' A data frame as a markdown table
md_table <- function(df, max_rows = 40) {
  if (is.null(df) || nrow(df) == 0) return("_none_")
  extra <- nrow(df) - max_rows
  df <- utils::head(df, max_rows)
  df[] <- lapply(df, function(x) gsub("|", "/", gsub("\n", " ", as.character(x), fixed = TRUE), fixed = TRUE))
  df[] <- lapply(df, function(x) ifelse(is.na(x), "", x))
  out <- c(paste0("| ", paste(names(df), collapse = " | "), " |"),
           paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
           apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
  if (extra > 0) out <- c(out, "", paste0("_... and ", extra, " more rows in the csv file_"))
  paste(out, collapse = "\n")
}

#' Versions of R and of the packages the pipeline uses
run_environment <- function() {
  pk <- c("tidyverse", "openxlsx", "readxl", "janitor", "yaml", "Hmisc", "stringdist", "arrow", "targets")
  v <- vapply(pk, function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(e) "not installed"), "")
  data.frame(item = c("R", "platform", names(v)),
             value = c(R.version.string, R.version$platform, unname(v)), stringsAsFactors = FALSE)
}

#' The settings, without anything that looks like a secret, and with paths shortened
sanitised_config <- function(cfg) {
  flat <- unlist(cfg, use.names = TRUE)
  flat <- flat[!grepl("password|token|secret|key", names(flat), ignore.case = TRUE)]
  is_path <- grepl("^([A-Za-z]:|/|~)", flat) | grepl("[/\\\\].+[.](xlsx|csv)$", flat)
  flat[is_path] <- basename(flat[is_path])
  data.frame(setting = names(flat), value = unname(as.character(flat)), stringsAsFactors = FALSE)
}

# Runs: where they are written, and which earlier run to compare with ----

diag_dir <- function(kind, root = file.path("data", "output", "diagnostics")) file.path(root, kind)

new_run_id <- function() format(Sys.time(), "%Y-%m-%d_%H%M%S")

#' The profile of the newest earlier run that worked (NULL if there is none)
previous_profile <- function(kind, current_id = NULL) {
  base <- diag_dir(kind)
  runs <- sort(list.files(base, pattern = "^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}$"), decreasing = TRUE)
  runs <- setdiff(runs, current_id)
  for (r in runs) {
    p <- file.path(base, r, "profile.rds")
    if (!file.exists(p)) next
    prof <- tryCatch(readRDS(p), error = function(e) NULL)
    if (!is.null(prof) && isTRUE(prof$ok)) return(prof)
  }
  NULL
}

#' Rows of an earlier table that belong to flows that were NOT run now (so a run of one flow keeps
#' the last known state of the others, and each flow is compared with its own last run)
other_flows <- function(base_df, flows) {
  if (is.null(base_df) || !"flow" %in% names(base_df)) return(NULL)
  base_df[!base_df$flow %in% flows, , drop = FALSE]
}

#' Write the files of one run and copy them to `latest/`
write_diagnostics <- function(kind, run_id, report, tables, profile, log_lines) {
  dir <- file.path(diag_dir(kind), run_id)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  writeLines(report, file.path(dir, "report.md"), useBytes = TRUE)
  for (nm in names(tables)) {
    utils::write.csv(tables[[nm]], file.path(dir, paste0(nm, ".csv")), row.names = FALSE, na = "")
  }
  writeLines(if (length(log_lines)) log_lines else "(no messages or warnings)", file.path(dir, "run.log"), useBytes = TRUE)
  saveRDS(profile, file.path(dir, "profile.rds"))

  latest <- file.path(diag_dir(kind), "latest")
  unlink(latest, recursive = TRUE)
  dir.create(latest, recursive = TRUE, showWarnings = FALSE)
  file.copy(list.files(dir, full.names = TRUE), latest)
  invisible(dir)
}

#' Run a set of flows and collect what the report needs
#'
#' `flows` is a named list of functions. Each flow runs on its own: if one fails, the others still
#' run, and the failure is recorded. Messages and warnings are collected into the run log (they are
#' still printed as usual). The legacy scripts remove all functions from the global environment
#' (`rm(list = ls())`), so the project code is loaded again after every flow.
run_flows_collecting <- function(flows) {
  reload  <- source_project            # kept in this frame: the scripts cannot remove it
  log     <- character()
  failures <- list()
  add_log <- function(type, text) log <<- c(log, paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", type, ": ", trimws(text)))

  for (nm in names(flows)) {
    diag_flow(nm)
    t0 <- Sys.time()
    withCallingHandlers(
      tryCatch(flows[[nm]](),
               error = function(e) {
                 reload()                                  # the script may have removed the functions
                 tr <- trace_get()
                 failures[[nm]] <<- list(error = conditionMessage(e), step = utils::tail(tr$step[tr$flow == nm], 1))
                 add_log("ERROR", paste0("flow ", nm, " FAILED: ", conditionMessage(e)))
               }),
      warning = function(w) add_log("WARNING", conditionMessage(w)),
      message = function(m) add_log("MESSAGE", conditionMessage(m)))
    add_log("MESSAGE", sprintf("flow %s finished in %.0f s", nm, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
    reload()
  }
  list(log = log, failures = failures)
}
