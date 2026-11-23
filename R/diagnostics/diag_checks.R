# Diagnostics: checks ----
# What the checks found in this run and what changed since the last run that worked: how many
# issues of each kind, which issues are new or solved, which log_decisions entries do not match any
# check, and how many rows the checks looked at. It reads the Excel files that the check scripts
# write (same files, same format), so it needs no change to the checks themselves.

# The workbooks each flow writes. (Older versions of the CR number checks also saved a half-way
# "Number checks.xlsx"; it is not written any more and is not read here.)
checks_workbooks <- list(
  cr = c("Data checks.xlsx", "New checks.xlsx", "Number checks - Reached.xlsx", "Number checks - Targeted.xlsx"),
  pr = c("Data checks.xlsx", "Number checks.xlsx")
)

checks_scripts <- list(
  cr = c("scripts/cr/checks/cr_data_checks.R", "scripts/cr/checks/cr_data_checks_new.R",
         "scripts/cr/checks/cr_numbers_checks_reached.R", "scripts/cr/checks/cr_numbers_checks_targeted.R"),
  pr = c("scripts/pr/checks/pr_data_checks.R", "scripts/pr/checks/pr_number_checks.R")
)

ID_COLS <- c("ProgrammeID", "LeadGRN", "GMGRN", "code", "AnalysisCode")

# Reading the workbooks ----

find_col <- function(df, pattern) {
  hit <- grep(pattern, names(df), ignore.case = TRUE, value = TRUE)
  if (length(hit)) hit[1] else NA_character_
}

#' Profile one checks workbook: its sheets and the issues it reports
profile_workbook <- function(path, flow, workbook) {
  sheets <- openxlsx::getSheetNames(path)
  data <- lapply(stats::setNames(sheets, sheets), function(s) tryCatch(openxlsx::read.xlsx(path, sheet = s), error = function(e) NULL))

  sheet_tbl <- do.call(rbind, lapply(sheets, function(s) {
    d <- data[[s]]
    kind <- if (grepl("summary", s, ignore.case = TRUE)) "summary" else if (grepl("^cube", s, ignore.case = TRUE)) "cube" else "detail"
    data.frame(flow = flow, workbook = workbook, sheet = s, kind = kind,
               rows = if (is.null(d)) NA_integer_ else nrow(d), columns = if (is.null(d)) NA_integer_ else ncol(d),
               stringsAsFactors = FALSE)
  }))

  issues <- list(); keys <- list()
  summaries <- sheet_tbl$sheet[sheet_tbl$kind == "summary"]
  if (length(summaries)) {
    # the summary sheets list one row per issue found
    for (s in summaries) {
      d <- data[[s]]
      icol <- find_col(d, "^(issue|check)$")
      if (is.null(d) || is.na(icol) || nrow(d) == 0) next
      ids <- intersect(ID_COLS, names(d))
      key <- do.call(paste, c(d[ids], sep = "|"))
      issues[[s]] <- do.call(rbind, lapply(split(seq_len(nrow(d)), as.character(d[[icol]])), function(i) {
        data.frame(flow = flow, workbook = workbook, check = as.character(d[[icol]][i[1]]), n = length(unique(key[i])),
                   programmes = if ("ProgrammeID" %in% ids) length(unique(d$ProgrammeID[i])) else NA_integer_,
                   lead_grns = if ("LeadGRN" %in% ids) length(unique(d$LeadGRN[i])) else NA_integer_, stringsAsFactors = FALSE)
      }))
      keys[[s]] <- data.frame(flow = flow, workbook = workbook, check = as.character(d[[icol]]),
                              key = paste(key, as.character(d[[icol]]), sep = "|"), stringsAsFactors = FALSE)
    }
  } else {
    # no summary: the cube sheets hold one TRUE/FALSE column per check
    for (s in sheet_tbl$sheet[sheet_tbl$kind == "cube"]) {
      d <- data[[s]]
      if (is.null(d) || nrow(d) == 0) next
      flags <- names(d)[vapply(d, is.logical, logical(1))]
      ids <- intersect(c(ID_COLS, names(d)[1]), names(d))
      key <- do.call(paste, c(d[unique(ids)], sep = "|"))
      issues[[s]] <- do.call(rbind, lapply(flags, function(fl) {
        i <- which(d[[fl]] %in% TRUE)
        data.frame(flow = flow, workbook = workbook, check = paste0(s, ": ", fl), n = length(i),
                   programmes = if ("ProgrammeID" %in% names(d)) length(unique(d$ProgrammeID[i])) else NA_integer_,
                   lead_grns = if ("LeadGRN" %in% names(d)) length(unique(d$LeadGRN[i])) else NA_integer_, stringsAsFactors = FALSE)
      }))
      keys[[s]] <- do.call(rbind, lapply(flags, function(fl) {
        i <- which(d[[fl]] %in% TRUE)
        if (!length(i)) return(NULL)
        data.frame(flow = flow, workbook = workbook, check = paste0(s, ": ", fl), key = paste(key[i], fl, sep = "|"), stringsAsFactors = FALSE)
      }))
    }
  }

  # names that a log_decisions entry can use as `issue`: the check columns and the issue labels
  known <- unique(c(sheets,
                    unlist(lapply(data[sheet_tbl$sheet[sheet_tbl$kind == "cube"]], names)),
                    unlist(lapply(data[summaries], function(d) if (!is.null(d)) { ic <- find_col(d, "^(issue|check)$"); if (!is.na(ic)) as.character(d[[ic]]) }))))

  list(sheets = sheet_tbl,
       issues = do.call(rbind, issues),
       keys = do.call(rbind, keys),
       known = known)
}

#' Profile the checks of the flows that ran (only workbooks written during this run)
profile_checks <- function(flows_run, since, folder_date = Sys.Date()) {
  sheets <- list(); issues <- list(); keys <- list(); known <- list(); written <- list(); missing <- list()
  for (fl in flows_run) {
    dir <- file.path("data", "output", fl, folder_date)
    for (wb in checks_workbooks[[fl]]) {
      path <- file.path(dir, wb)
      if (!file.exists(path) || file.info(path)$mtime < since) { missing[[length(missing) + 1]] <- paste(fl, wb); next }
      p <- profile_workbook(path, fl, wb)
      sheets[[length(sheets) + 1]] <- p$sheets; issues[[length(issues) + 1]] <- p$issues; keys[[length(keys) + 1]] <- p$keys
      known[[fl]] <- unique(c(known[[fl]], p$known)); written[[length(written) + 1]] <- paste(fl, wb)
    }
  }
  sh <- do.call(rbind, sheets); is <- do.call(rbind, issues)
  overview <- do.call(rbind, lapply(written, function(w) {
    parts <- strsplit(w, " ", fixed = TRUE)[[1]]; fl <- parts[1]; wb <- paste(parts[-1], collapse = " ")
    data.frame(flow = fl, workbook = wb, sheets = sum(sh$flow == fl & sh$workbook == wb),
               issues_found = if (is.null(is)) 0 else sum(is$n[is$flow == fl & is$workbook == wb]), stringsAsFactors = FALSE)
  }))
  list(sheets = sh, issues = is, keys = do.call(rbind, keys), known = known,
       written = unlist(written), missing = unlist(missing), overview = overview)
}

# Log of decisions ----

#' Is `x` used as a name in the check scripts? (a quoted label or a bare column name, as a whole token)
used_in_scripts <- function(x, flow) {
  text <- paste(unlist(lapply(checks_scripts[[flow]], function(f) if (file.exists(f)) readLines(f, warn = FALSE))), collapse = " ")
  vapply(x, function(v) {
    pos <- gregexpr(v, text, fixed = TRUE)[[1]]
    if (pos[1] == -1) return(FALSE)
    before <- ifelse(pos > 1, substring(text, pos - 1, pos - 1), " ")
    after  <- substring(text, pos + nchar(v), pos + nchar(v))
    any(!grepl("[A-Za-z0-9_.]", before) & !grepl("[A-Za-z0-9_.]", after))
  }, logical(1))
}

#' Entries of log_decisions per flow, and the ones whose `issue` matches no check
#'
#' A check that currently finds nothing writes no issue, so an entry is only called unmatched when
#' its issue is neither in this run's workbooks nor a name used in the check scripts.
profile_log_decisions <- function(flows_run, known, used = decisions_used_rows(), hidden = decisions_get()) {
  path <- file.path("data", "input", "log_decisions", "log_decisions.xlsx")
  if (!file.exists(path)) return(list(summary = NULL, unmatched = NULL, found = FALSE))
  rows <- list(); unmatched <- list()
  for (fl in flows_run) {
    if (!fl %in% openxlsx::getSheetNames(path)) next
    d <- openxlsx::read.xlsx(path, sheet = fl)
    icol <- find_col(d, "^issue$")
    cand <- if (is.na(icol)) character() else setdiff(unique(trimws(as.character(d[[icol]]))), c(NA, "", known[[fl]]))
    bad  <- cand[!used_in_scripts(cand, fl)]
    n_used <- length(used[[fl]] %||% integer())
    rows[[fl]] <- data.frame(flow = fl, entries = nrow(d),
                             entries_that_hid_an_issue = n_used, entries_that_hid_nothing = nrow(d) - n_used,
                             issues_hidden = sum(hidden$ignored[hidden$flow == fl]),
                             entries_matching_no_check = if (is.na(icol)) NA else sum(trimws(as.character(d[[icol]])) %in% bad), stringsAsFactors = FALSE)
    if (length(bad)) unmatched[[fl]] <- data.frame(flow = fl, issue = bad, stringsAsFactors = FALSE)
  }
  list(summary = do.call(rbind, rows), unmatched = do.call(rbind, unmatched), hidden = hidden, found = TRUE)
}

# Comparison with the last run that worked ----

issue_comparison <- function(cur, base) {
  if (is.null(cur) || nrow(cur) == 0) return(NULL)
  cur$key <- paste(cur$flow, cur$workbook, cur$check, sep = "|")
  cur$last_run <- NA_integer_
  if (!is.null(base) && nrow(base)) {
    bkey <- paste(base$flow, base$workbook, base$check, sep = "|")
    cur$last_run <- base$n[match(cur$key, bkey)]
  }
  cur$change <- cur$n - cur$last_run
  cur[, c("flow", "workbook", "check", "n", "last_run", "change", "programmes", "lead_grns")]
}

compare_checks <- function(cur, base) {
  f <- no_findings()
  add <- function(...) f <<- rbind(f, finding(...))
  ic <- issue_comparison(cur$issues, base$issues)
  if (!is.null(ic)) {
    for (i in which(!is.na(ic$change) & ic$change > 0)) add("attention", paste(ic$flow[i], ic$workbook[i], sep = " / "), "more issues than in the last run", sprintf("%s: %s -> %s", ic$check[i], ic$last_run[i], ic$n[i]))
    for (i in which(!is.na(ic$change) & ic$change < 0)) add("info", paste(ic$flow[i], ic$workbook[i], sep = " / "), "fewer issues than in the last run", sprintf("%s: %s -> %s", ic$check[i], ic$last_run[i], ic$n[i]))
    for (i in which(is.na(ic$last_run) & ic$n > 0)) add("attention", paste(ic$flow[i], ic$workbook[i], sep = " / "), "new kind of issue (not reported in the last run)", sprintf("%s: %s", ic$check[i], ic$n[i]))
  }
  if (!is.null(base$issues) && nrow(base$issues)) {
    gone <- base$issues[!paste(base$issues$flow, base$issues$workbook, base$issues$check) %in%
                          paste(cur$issues$flow, cur$issues$workbook, cur$issues$check), ]
    # only for workbooks written in this run
    gone <- gone[paste(gone$flow, gone$workbook) %in% cur$written, ]
    for (i in seq_len(nrow(gone))) add("info", paste(gone$flow[i], gone$workbook[i], sep = " / "), "kind of issue no longer reported", sprintf("%s (was %s)", gone$check[i], gone$n[i]))
  }
  # sheets that appeared or disappeared
  if (!is.null(base$sheets)) {
    k <- function(s) paste(s$flow, s$workbook, s$sheet, sep = " / ")
    bs <- base$sheets[paste(base$sheets$flow, base$sheets$workbook) %in% cur$written, ]
    new_s <- setdiff(k(cur$sheets), k(bs)); gone_s <- setdiff(k(bs), k(cur$sheets))
    if (length(new_s))  add("info", "sheets", "new sheet(s): a check now finds issues", short_list(new_s))
    if (length(gone_s)) add("info", "sheets", "sheet(s) no longer written: the check finds nothing", short_list(gone_s))
  }
  f
}

#' New and solved issues since the last run, as a table of identifiers (no values)
issue_changes <- function(cur, base) {
  if (is.null(base$keys) || is.null(cur$keys)) return(data.frame(status = character(), flow = character(), workbook = character(), check = character(), key = character()))
  pairs <- unique(cur$keys[, c("flow", "workbook")])
  b <- base$keys[paste(base$keys$flow, base$keys$workbook) %in% paste(pairs$flow, pairs$workbook), ]
  ck <- paste(cur$keys$flow, cur$keys$workbook, cur$keys$key); bk <- paste(b$flow, b$workbook, b$key)
  new <- cur$keys[!ck %in% bk, ]; solved <- b[!bk %in% ck, ]
  rbind(if (nrow(new)) cbind(status = "new", new), if (nrow(solved)) cbind(status = "solved", solved))
}

# Checks that do not need an earlier run ----

checks_sanity <- function(cfg, flows_run, cur, logd, failures, log_lines) {
  f <- no_findings()
  add <- function(...) f <<- rbind(f, finding(...))
  for (nm in names(failures)) add("attention", nm, "the flow failed", failures[[nm]]$error)
  for (m in cur$missing) add("attention", m, "workbook not written in this run", "the check scripts did not produce it: see the log and the failed flows")

  # cleaned file older than the Combiner output: the checks would run on old data
  fl_in <- list(cr = list(cleaned = "CR Combiner - For Checks.csv", input = cfg$combiner_cr),
                pr = list(cleaned = "PR Combiner - For Checks.csv", input = cfg$combiner_pr))
  for (fl in intersect(flows_run, names(fl_in))) {
    cl <- file.path("data", "cleaned", fl_in[[fl]]$cleaned); inp <- file.path("data", "input", fl_in[[fl]]$input)
    if (file.exists(cl) && file.exists(inp) && file.info(cl)$mtime < file.info(inp)$mtime)
      add("attention", toupper(fl), "cleaned file is older than the Combiner input", sprintf("run the cleaning again: %s is older than %s", fl_in[[fl]]$cleaned, fl_in[[fl]]$input))
  }

  if (!isTRUE(logd$found)) {
    add("attention", "log_decisions", "log_decisions.xlsx not found", "the checks cannot run without it")
  } else if (!is.null(logd$unmatched)) {
    for (fl in unique(logd$unmatched$flow))
      add("attention", paste("log_decisions /", fl), "entries whose issue matches no check: they filter nothing (misspelled?)", short_list(logd$unmatched$issue[logd$unmatched$flow == fl]))
  }
  if (isTRUE(logd$found) && !is.null(logd$summary)) {
    for (i in seq_len(nrow(logd$summary))) {
      s <- logd$summary[i, ]
      if (s$entries_that_hid_nothing > 0)
        add("info", paste("log_decisions /", s$flow), "entries that hid no issue in this run (the issue may be solved: they can be removed)",
            sprintf("%d of %d entries", s$entries_that_hid_nothing, s$entries))
    }
  }
  warn <- grep("WARNING", log_lines, value = TRUE)
  warn <- warn[!grepl("built under R version|summarise[(][)] has grouped output|`summarise[(][)]`", warn)]
  if (length(warn)) add("attention", "run", "warnings during the run", sprintf("%d (see run.log)", length(warn)))
  f
}

# Report ----

render_checks_report <- function(info) {
  att <- info$findings[info$findings$severity == "attention", ]
  inf <- info$findings[info$findings$severity == "info", ]
  nfail <- length(info$failures)
  status <- if (nfail) sprintf("**%d flow(s) FAILED.** The other flows were checked. See \"Failed flows\".", nfail)
            else if (nrow(att)) sprintf("**%d point(s) need attention.** Read section 1.", nrow(att))
            else "**Nothing needs attention.**"
  cmp <- if (is.null(info$base)) "First run: there is no earlier run to compare with." else
         sprintf("Compared with the last run that worked (%s).", info$base$run_id)
  ch <- info$changes
  ch_txt <- if (is.null(info$base)) "_no earlier run_" else
    sprintf("%d new issue(s) and %d solved issue(s) since the last run. The list is in `changes.csv` (it contains programme and grant numbers).",
            sum(ch$status == "new"), sum(ch$status == "solved"))

  out <- c(paste0("# Checks report ", info$run_id), "", status, "", cmp, "",
           "## 1. Attention", "", md_table(att[, c("area", "item", "detail")]), "",
           "## 2. Information", "", md_table(inf[, c("area", "item", "detail")]), "")
  if (nfail) {
    out <- c(out, "## Failed flows", "",
             md_table(data.frame(flow = names(info$failures),
                                 last_step_that_worked = vapply(info$failures, function(z) if (length(z$step)) z$step else "(none)", ""),
                                 error = vapply(info$failures, function(z) z$error, ""))), "")
  }
  out <- c(out, "## 3. Issues by check", "", ch_txt, "", md_table(info$comparison, max_rows = 80), "",
           "## 4. Workbooks written", "", md_table(info$checks$overview), "",
           "## 5. Row trace", "",
           "Rows each check script looked at, after the filters that choose the programmes in scope.", "",
           md_table(info$trace_view[, c("flow", "step", "rows", "change", "last_run")], max_rows = 80), "",
           "## 6. Log of decisions", "",
           "`log_decisions.xlsx` is applied by the check scripts: an issue with a matching entry is removed from the workbooks. The report counts what the log removed, so that issues found = issues reported + issues hidden.", "",
           md_table(info$log_decisions$summary), "",
           "Issues hidden by the log, per check:", "", md_table(info$log_decisions$hidden, max_rows = 60), "",
           "## 7. Messages and warnings", "",
           if (length(info$log)) paste0("```\n", paste(utils::head(info$log, 60), collapse = "\n"), "\n```") else "_none_", "",
           "## 8. Environment", "", md_table(run_environment()), "",
           "## 9. Settings", "", md_table(sanitised_config(info$cfg), max_rows = 60), "")
  out
}

# Entry point ----

#' Run the checks and write the checks report
#'
#' @param flows Which flows to run: any of "cr", "pr".
run_checks_with_diagnostics <- function(cfg, flows = c("cr", "pr")) {
  force(cfg); force(flows)   # the legacy scripts remove global variables: evaluate the arguments now
  run_id <- new_run_id()
  since  <- Sys.time() - 1
  diag_reset()
  job <- stats::setNames(lapply(flows, function(nm) {
    s <- checks_scripts[[nm]]
    function() for (f in s) source(f)
  }), flows)
  res <- run_flows_collecting(job)

  cur  <- profile_checks(flows, since)
  logd <- profile_log_decisions(flows, cur$known)   # reads what the check scripts recorded with diag_decisions()
  base <- previous_profile("checks", run_id)
  tv   <- trace_view(trace_get(), base$trace)

  findings <- rbind(checks_sanity(cfg, flows, cur, logd, res$failures, res$log),
                    if (!is.null(base)) compare_checks(cur, base$checks),
                    if (!is.null(base)) first_trace_difference(tv))
  findings <- findings[order(findings$severity != "attention"), ]
  comparison <- issue_comparison(cur$issues, base$checks$issues)
  changes <- if (!is.null(base)) issue_changes(cur, base$checks) else NULL

  info <- list(run_id = run_id, cfg = cfg, findings = findings, failures = res$failures, base = base, checks = cur,
               comparison = comparison, changes = changes, trace_view = tv, log_decisions = logd, log = res$log)
  # the profile keeps the identifiers of the issues, so that the next run can tell new from solved
  keep <- base$checks
  merged <- list(sheets = rbind(cur$sheets, other_flows(keep$sheets, flows)),
                 issues = rbind(cur$issues, other_flows(keep$issues, flows)),
                 keys = rbind(cur$keys, other_flows(keep$keys, flows)),
                 overview = rbind(cur$overview, other_flows(keep$overview, flows)),
                 known = c(cur$known, keep$known[setdiff(names(keep$known), names(cur$known))]),
                 written = c(cur$written, keep$written[!sub(" .*$", "", keep$written) %in% flows]),
                 missing = cur$missing)
  profile <- list(ok = length(res$failures) == 0, run_id = run_id, flows = flows, checks = merged,
                  trace = rbind(trace_get(), other_flows(base$trace, flows)))
  dir <- write_diagnostics("checks", run_id, render_checks_report(info),
                           list(findings = findings, issues = comparison, hidden_by_log = logd$hidden, sheets = cur$sheets,
                                trace = tv, changes = changes %||% data.frame()),
                           profile, res$log)
  message("Checks report: ", file.path(dir, "report.md"))
  invisible(list(dir = dir, findings = findings, failures = res$failures))
}
