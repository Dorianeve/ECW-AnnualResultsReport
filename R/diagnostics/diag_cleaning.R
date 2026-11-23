# Diagnostics: cleaning ----
# What the cleaning scripts (CR, PR, MnE tracker) did in this run, and what changed since the
# last run that worked. Reads the cleaned csv files (fast) plus what the scripts recorded with
# `diag_input()` and `trace_step()`.

# Flow -> cleaned file and input file
cleaning_flows <- function(cfg) {
  list(
    cr  = list(output = "CR Combiner - For Checks", input = file.path("data", "input", cfg$combiner_cr), label = cfg$combiner_cr),
    pr  = list(output = "PR Combiner - For Checks", input = file.path("data", "input", cfg$combiner_pr), label = cfg$combiner_pr),
    mne = list(output = "MnE Report Tracker",       input = cfg$mne_approval,                            label = "MnE tracker")
  )
}

# Profiles ----

#' Columns, row count, share of empty cells and category values of one table
profile_df <- function(d, max_levels = DIAG$max_levels) {
  cats <- list()
  for (col in names(d)) {
    x <- d[[col]]
    few <- length(unique(x[!is.na(x)])) <= (if (is.numeric(x)) 20 else max_levels)
    if (!few || !(is.character(x) || is.factor(x) || is.logical(x) || is.numeric(x))) next
    tab <- table(as.character(x))
    cats[[col]] <- stats::setNames(as.integer(tab), names(tab))
  }
  na_rate <- vapply(d, function(x) round(mean(if (is.character(x)) is.na(x) | trimws(x) == "" else is.na(x)), 4), numeric(1))
  list(n = nrow(d), columns = names(d), na_rate = na_rate, categories = cats,
       n_distinct = vapply(d, function(x) length(unique(x[!is.na(x)])), integer(1)))
}

#' Profile the cleaned file of every flow that ran (a flow that failed has no new file)
profile_cleaned <- function(cfg, flows_run, failed) {
  fl <- cleaning_flows(cfg)
  out <- list()
  for (nm in setdiff(flows_run, failed)) {
    f <- file.path("data", "cleaned", paste0(fl[[nm]]$output, ".csv"))
    if (!file.exists(f)) next
    out[[fl[[nm]]$output]] <- profile_df(utils::read.csv(f, encoding = "UTF-8", check.names = FALSE))
  }
  out
}

#' One row per input file: size, date, rows and columns
inventory_inputs <- function(cfg, flows_run) {
  fl <- cleaning_flows(cfg)
  rows <- lapply(flows_run, function(nm) {
    f <- fl[[nm]]$input
    info <- if (file.exists(f)) file.info(f) else NULL
    cap  <- .diag_env$inputs[[fl[[nm]]$label]]
    data.frame(flow = nm, file = fl[[nm]]$label, found = !is.null(info),
               size_kb = if (is.null(info)) NA else round(info$size / 1024),
               modified = if (is.null(info)) NA else format(info$mtime, "%Y-%m-%d %H:%M"),
               rows = cap$rows %||% NA, columns = if (is.null(cap)) NA else length(cap$columns), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

#' Columns of each input and whether the same name is still there after cleaning
schema_table <- function(cfg, flows_run, cleaned) {
  fl <- cleaning_flows(cfg)
  rows <- lapply(flows_run, function(nm) {
    cap <- .diag_env$inputs[[fl[[nm]]$label]]
    if (is.null(cap)) return(NULL)
    out_cols <- cleaned[[fl[[nm]]$output]]$columns
    clean_name <- gsub("\\s+", "", cap$columns)
    data.frame(flow = nm, file = fl[[nm]]$label, column = cap$columns,
               kept_name_in_output = if (is.null(out_cols)) NA else clean_name %in% out_cols,
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

outputs_table <- function(cleaned) {
  rows <- lapply(names(cleaned), function(nm) {
    p <- cleaned[[nm]]
    data.frame(table = nm, column = p$columns, rows = p$n, empty_share = unname(p$na_rate[p$columns]),
               n_distinct = unname(p$n_distinct[p$columns]), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# Comparison with the last run that worked ----

compare_cleaned <- function(cur, base) {
  f <- no_findings()
  add <- function(...) f <<- rbind(f, finding(...))
  for (nm in names(cur)) {
    c1 <- cur[[nm]]; b1 <- base[[nm]]
    if (is.null(b1)) { add("info", nm, "no earlier profile", "this table was not in the last run"); next }

    new_c <- setdiff(c1$columns, b1$columns); gone_c <- setdiff(b1$columns, c1$columns)
    if (length(new_c))  add("attention", nm, "new output column", short_list(new_c))
    if (length(gone_c)) add("attention", nm, "output column disappeared", short_list(gone_c))

    if (b1$n > 0 && abs(c1$n - b1$n) / b1$n >= DIAG$rows_change && abs(c1$n - b1$n) >= DIAG$trace_min_rows) {
      add("attention", nm, "row count changed", sprintf("%s -> %s (%+.0f%%)", b1$n, c1$n, 100 * (c1$n - b1$n) / b1$n))
    }

    shared <- intersect(c1$columns, b1$columns)
    jump <- shared[abs(c1$na_rate[shared] - b1$na_rate[shared]) >= DIAG$na_jump]
    if (length(jump)) {
      add("attention", nm, "share of empty cells changed in",
          short_list(sprintf("%s (%.0f%% -> %.0f%%)", jump, 100 * b1$na_rate[jump], 100 * c1$na_rate[jump])))
    }

    for (col in intersect(names(c1$categories), names(b1$categories))) {
      new_v  <- setdiff(names(c1$categories[[col]]), names(b1$categories[[col]]))
      gone_v <- setdiff(names(b1$categories[[col]]), names(c1$categories[[col]]))
      if (length(new_v))  add("attention", nm, paste0("new value(s) in ", col), short_list(new_v))
      if (length(gone_v)) add("info", nm, paste0("value(s) no longer in ", col), short_list(gone_v))
    }
  }
  f
}

compare_inputs <- function(cur_inputs, base_inputs, inv, base_inv) {
  f <- no_findings()
  add <- function(...) f <<- rbind(f, finding(...))
  for (nm in names(cur_inputs)) {
    b <- base_inputs[[nm]]
    if (is.null(b)) next
    new_c <- setdiff(cur_inputs[[nm]]$columns, b$columns); gone_c <- setdiff(b$columns, cur_inputs[[nm]]$columns)
    if (length(new_c))  add("attention", nm, "new column in input", short_list(new_c))
    if (length(gone_c)) add("attention", nm, "column no longer in input", short_list(gone_c))
    r0 <- b$rows; r1 <- cur_inputs[[nm]]$rows
    if (r0 > 0 && abs(r1 - r0) / r0 >= DIAG$rows_change && abs(r1 - r0) >= DIAG$trace_min_rows) {
      add("attention", nm, "input row count changed", sprintf("%s -> %s (%+.0f%%)", r0, r1, 100 * (r1 - r0) / r0))
    }
  }
  if (!is.null(base_inv)) {
    for (i in seq_len(nrow(inv))) {
      j <- match(inv$file[i], base_inv$file)
      if (!is.na(j) && !identical(inv$modified[i], base_inv$modified[j])) {
        add("info", inv$file[i], "input file is newer than in the last run", sprintf("%s -> %s", base_inv$modified[j], inv$modified[i]))
      }
    }
  }
  f
}

#' Row trace: change against the previous step, and the same step in the last run
trace_view <- function(trace, base_trace = NULL) {
  if (nrow(trace) == 0) { trace$change <- integer(); trace$last_run <- integer(); return(trace) }   # nothing traced: every flow failed early
  trace$change <- NA_integer_
  group <- paste(trace$flow, sub(":.*$", "", trace$step))   # steps of one script follow each other
  for (g in unique(group)) {
    i <- which(group == g)
    trace$change[i] <- c(NA, diff(trace$rows[i]))
  }
  trace$last_run <- NA_integer_
  if (!is.null(base_trace) && nrow(base_trace)) {
    key <- paste(trace$flow, trace$step, sep = "|"); bkey <- paste(base_trace$flow, base_trace$step, sep = "|")
    trace$last_run <- base_trace$rows[match(key, bkey)]
  }
  trace
}

#' The first step of each flow where the row count differs from the last run
first_trace_difference <- function(tv) {
  f <- no_findings()
  for (fl in unique(tv$flow)) {
    d <- tv[tv$flow == fl & !is.na(tv$last_run) & tv$rows != tv$last_run, ]
    if (nrow(d)) f <- rbind(f, finding("attention", fl, "row counts start to differ from the last run at this step",
                                       sprintf("%s: %s rows (last run %s)", d$step[1], d$rows[1], d$last_run[1])))
  }
  f
}

# Checks that do not need an earlier run ----

cleaning_sanity <- function(cfg, cleaned, flows_run, failures, log_lines) {
  f <- no_findings()
  add <- function(...) f <<- rbind(f, finding(...))
  for (nm in names(failures)) add("attention", nm, "the flow failed", failures[[nm]]$error)

  warn <- grep("WARNING", log_lines, value = TRUE)
  warn <- warn[!grepl("built under R version", warn)]
  if (length(warn)) add("attention", "run", "warnings during the run", sprintf("%d (see run.log)", length(warn)))

  for (nm in intersect(c("CR Combiner - For Checks", "PR Combiner - For Checks"), names(cleaned))) {
    if ((cleaned[[nm]]$na_rate["exercice"] %||% 0) > 0)
      add("attention", nm, "rows with an Exercise that is not encoded", sprintf("%.1f%% of rows have no `exercice` code: check the Exercise labels", 100 * cleaned[[nm]]$na_rate["exercice"]))
    ex <- cleaned[[nm]]$categories[["exercice"]]
    if (is.null(ex)) next
    if (!as.character(cfg$annual) %in% names(ex))
      add("attention", nm, "no rows for the annual exercise", sprintf("exercice == %s (annual) is not in the data", cfg$annual))
    if (!as.character(cfg$cumulative) %in% names(ex))
      add("attention", nm, "no rows for the cumulative exercise", sprintf("exercice == %s (cumulative) is not in the data", cfg$cumulative))
  }
  d <- cleaned[["CR Combiner - For Checks"]]
  if (!is.null(d) && !is.null(d$categories$Sourceofdata) && !cfg$source_cr %in% names(d$categories$Sourceofdata))
    add("attention", "CR Combiner - For Checks", "current source of data not found", sprintf("Sourceofdata has no '%s'", cfg$source_cr))
  d <- cleaned[["PR Combiner - For Checks"]]
  if (!is.null(d) && !is.null(d$categories$Sourceofdata) && !cfg$source_pr %in% names(d$categories$Sourceofdata))
    add("attention", "PR Combiner - For Checks", "current source of data not found", sprintf("Sourceofdata has no '%s'", cfg$source_pr))
  f
}

# Report ----

render_cleaning_report <- function(info) {
  att  <- info$findings[info$findings$severity == "attention", ]
  inf  <- info$findings[info$findings$severity == "info", ]
  nfail <- length(info$failures)
  status <- if (nfail) sprintf("**%d flow(s) FAILED.** The other flows were cleaned. See \"Failed flows\".", nfail)
            else if (nrow(att)) sprintf("**%d point(s) need attention.** Read section 1.", nrow(att))
            else "**Nothing needs attention.**"
  cmp <- if (is.null(info$base)) "First run: there is no earlier run to compare with." else
         sprintf("Compared with the last run that worked (%s).", info$base$run_id)

  out <- c(paste0("# Cleaning report ", info$run_id), "",
           status, "", cmp, "",
           "## 1. Attention", "", md_table(att[, c("area", "item", "detail")]), "",
           "## 2. Information", "", md_table(inf[, c("area", "item", "detail")]), "")

  if (nfail) {
    out <- c(out, "## Failed flows", "",
             md_table(data.frame(flow = names(info$failures),
                                 last_step_that_worked = vapply(info$failures, function(z) if (length(z$step)) z$step else "(none)", ""),
                                 error = vapply(info$failures, function(z) z$error, ""))), "")
  }

  sizes <- do.call(rbind, lapply(names(info$cleaned), function(nm) {
    data.frame(table = nm, rows = info$cleaned[[nm]]$n, columns = length(info$cleaned[[nm]]$columns),
               last_run = if (is.null(info$base$cleaned[[nm]])) NA else info$base$cleaned[[nm]]$n, stringsAsFactors = FALSE)
  }))
  out <- c(out, "## 3. Output size", "", md_table(sizes), "",
           "## 4. Row trace", "",
           "Rows after each step. A step marked \"should not add rows\" must show a change of 0.", "",
           md_table(info$trace_view[, c("flow", "step", "rows", "change", "last_run")], max_rows = 80), "",
           "## 5. Input files", "", md_table(info$inventory), "",
           "## 6. Messages and warnings", "",
           if (length(info$log)) paste0("```\n", paste(utils::head(info$log, 60), collapse = "\n"), "\n```") else "_none_", "",
           "## 7. Environment", "", md_table(run_environment()), "",
           "## 8. Settings", "", md_table(sanitised_config(info$cfg), max_rows = 60), "")
  out
}

# Entry point ----

#' Run the cleaning flows and write the cleaning report
#'
#' @param flows Which flows to run: any of "cr", "pr", "mne".
run_cleaning_with_diagnostics <- function(cfg, flows = c("cr", "pr", "mne")) {
  force(cfg); force(flows)   # the legacy scripts remove global variables: evaluate the arguments now
  scripts <- list(cr  = "scripts/cr/cleaning/cr_cleaning.R",
                  pr  = "scripts/pr/cleaning/pr_cleaning.R",
                  mne = "scripts/mne/mne_cleaning.R")
  run_id <- new_run_id()
  diag_reset()
  job <- stats::setNames(lapply(flows, function(nm) { s <- scripts[[nm]]; function() source(s) }), flows)
  res <- run_flows_collecting(job)

  failed  <- names(res$failures)
  inputs  <- .diag_env$inputs
  cleaned <- profile_cleaned(cfg, flows, failed)
  inv     <- inventory_inputs(cfg, flows)
  base    <- previous_profile("cleaning", run_id)
  tv      <- trace_view(trace_get(), base$trace)

  findings <- rbind(cleaning_sanity(cfg, cleaned, flows, res$failures, res$log),
                    if (!is.null(base)) compare_cleaned(cleaned, base$cleaned),
                    if (!is.null(base)) compare_inputs(inputs, base$inputs, inv, base$inventory),
                    if (!is.null(base)) first_trace_difference(tv))
  findings <- findings[order(findings$severity != "attention"), ]

  info <- list(run_id = run_id, cfg = cfg, findings = findings, failures = res$failures, base = base,
               cleaned = cleaned, trace_view = tv, inventory = inv, log = res$log)
  # the profile also keeps the last known state of the flows that were not run now
  profile <- list(ok = length(failed) == 0, run_id = run_id, flows = flows,
                  cleaned = c(cleaned, base$cleaned[setdiff(names(base$cleaned), names(cleaned))]),
                  inputs = c(inputs, base$inputs[setdiff(names(base$inputs), names(inputs))]),
                  inventory = rbind(inv, other_flows(base$inventory, flows)),
                  trace = rbind(trace_get(), other_flows(base$trace, flows)))
  dir <- write_diagnostics("cleaning", run_id, render_cleaning_report(info),
                           list(findings = findings, trace = tv, inputs = inv,
                                schema = schema_table(cfg, flows, cleaned), outputs = outputs_table(cleaned)),
                           profile, res$log)
  message("Cleaning report: ", file.path(dir, "report.md"))
  invisible(list(dir = dir, findings = findings, failures = res$failures))
}
