# Row trace and input capture ----
# `trace_step()` records how many rows a table has at a given point of a flow and returns the
# table unchanged, so it can sit inside a pipe or on its own line:
#
#   df <- df |> dplyr::filter(...) |> trace_step("CR: after dropping rows without a GRN")
#   trace_step(df, "PR: after cleaning the Total column")
#
# The diagnostics report shows these counts step by step and compares them with the previous run.
#
# The state lives in objects whose names start with a dot. The cleaning scripts call
# `rm(list = ls())`, which does not remove dot-objects, so the trace survives it.

if (!exists(".diag_env", inherits = FALSE)) {
  .diag_env <- new.env()
  .diag_env$flow   <- "-"
  .diag_env$steps  <- list()
  .diag_env$inputs <- list()
  .diag_env$decisions <- list()
}

#' Forget everything recorded so far
diag_reset <- function() {
  .diag_env$flow <- "-"; .diag_env$steps <- list(); .diag_env$inputs <- list(); .diag_env$decisions <- list()
  invisible(NULL)
}

#' Name the flow the next trace steps belong to ("cr", "pr", "mne", "checks"...)
diag_flow <- function(flow) {
  .diag_env$flow <- flow
  invisible(flow)
}

#' Record the number of rows of `x` under `label` and return `x`
trace_step <- function(x, label) {
  n <- if (is.data.frame(x)) nrow(x) else length(x)
  .diag_env$steps[[length(.diag_env$steps) + 1]] <-
    list(flow = .diag_env$flow, step = as.character(label), rows = as.integer(n))
  x
}

#' Record the size and the column names of an input table, right after reading it
diag_input <- function(x, name) {
  .diag_env$inputs[[name]] <- list(flow = .diag_env$flow, rows = nrow(x), columns = names(x))
  invisible(x)
}

#' The recorded steps as a data frame (flow, step, rows), in the order they happened
trace_get <- function() {
  s <- .diag_env$steps
  if (length(s) == 0) {
    return(data.frame(flow = character(), step = character(), rows = integer(), stringsAsFactors = FALSE))
  }
  data.frame(flow = vapply(s, function(z) z$flow, ""), step = vapply(s, function(z) z$step, ""),
             rows = vapply(s, function(z) z$rows, 1L), stringsAsFactors = FALSE)
}

#' Record what the log of decisions removes from a check (call it just BEFORE the log is applied)
#'
#' `x` is the table the log is applied to, with a `Concat` column; `log` has the same `Concat`.
#' Two shapes exist in the check scripts: the long cube (columns `Issue` and `Flag`: only flagged
#' issues count) and the summary (one row per issue, column `Check` or `issue`).
diag_decisions <- function(x, log, script) {
  if (!is.data.frame(x) || !"Concat" %in% names(x) || is.null(log$Concat)) return(invisible(x))
  long <- all(c("Issue", "Flag") %in% names(x))
  icol <- if (long) "Issue" else intersect(c("Check", "issue", "Issue"), names(x))[1]
  if (is.na(icol)) return(invisible(x))
  hit <- x$Concat %in% log$Concat & (if (long) x[["Flag"]] %in% TRUE else TRUE)
  keys <- unique(data.frame(check = as.character(x[[icol]][hit]), concat = x$Concat[hit], stringsAsFactors = FALSE))
  ignored <- if (nrow(keys)) as.data.frame(table(check = keys$check), responseName = "ignored", stringsAsFactors = FALSE)
             else data.frame(check = character(), ignored = integer(), stringsAsFactors = FALSE)
  .diag_env$decisions[[length(.diag_env$decisions) + 1]] <-
    list(flow = .diag_env$flow, script = script, ignored = ignored, used_rows = which(log$Concat %in% x$Concat[hit]),
         log_entries = nrow(log))
  invisible(x)
}

#' What the log of decisions removed so far: one row per script and check
decisions_get <- function() {
  d <- .diag_env$decisions
  if (length(d) == 0) return(data.frame(flow = character(), script = character(), check = character(), ignored = integer(), stringsAsFactors = FALSE))
  do.call(rbind, lapply(d, function(z) if (nrow(z$ignored)) data.frame(flow = z$flow, script = z$script, z$ignored, stringsAsFactors = FALSE)))
}

#' Log rows (by position) that removed at least one issue, per flow
decisions_used_rows <- function() {
  d <- .diag_env$decisions
  fl <- unique(vapply(d, function(z) z$flow, ""))
  stats::setNames(lapply(fl, function(f) sort(unique(unlist(lapply(d[vapply(d, function(z) z$flow, "") == f], function(z) z$used_rows))))), fl)
}
