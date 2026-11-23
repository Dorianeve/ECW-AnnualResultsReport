# Debug mode ----
# The legacy scripts end with `rm(list = ls())`, so after a run (or after an error in the next
# script) the data frames are gone and cannot be looked at. With debug mode on, the scripts keep
# their objects:
#
#   arr_debug()          # on: the objects stay in the R session (df, cube, summary, ...)
#   source("scripts/cr/checks/cr_data_checks.R")
#   View(df)             # look at the data the script stopped on
#   arr_debug(FALSE)     # off again (the normal behaviour)
#
# Use it when you run ONE script at a time in RStudio or an R console. For a normal run leave it off.

arr_debug <- function(on = TRUE) {
  options(arr.debug = on)
  message("Debug mode ", if (on) "ON: scripts keep their objects. Turn it off with arr_debug(FALSE)." else "OFF.")
  invisible(on)
}

#' The row trace recorded so far in this R session (see `trace_step()`), as a table
last_trace <- function() trace_get()
