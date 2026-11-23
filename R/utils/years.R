# Year helpers ----
# The year of the report is a setting (`report_year` in config.yml). These helpers turn it into the
# labels and codes the scripts need, so that a new year needs no change in the code.

#' Code of an exercise label: 2 x (last two digits) - 40 for "Annual", 2 x (last two digits) - 39 for "Cumulative"
#'
#' "ARR21 Annual" = 2, "ARR21 Cumulative" = 3, "ARR25 Annual" = 10, "ARR25 Cumulative" = 11,
#' "ARR26 Annual" = 12 ... The code of the year is `annual` / `cumulative` in config.yml.
#' Labels the rule does not know (and the years before 2020) give NA.
#' @param x Character vector of exercise labels.
#' @return Numeric vector.
encode_exercise <- function(x) {
  m <- stringr::str_match(tolower(as.character(x)), "([0-9]{2}) (annual|cumulative)")
  yy <- suppressWarnings(as.numeric(m[, 2]))
  code <- ifelse(m[, 3] == "annual", 2 * yy - 40, 2 * yy - 39)
  ifelse(!is.na(code) & code >= 1, code, NA_real_)
}

#' Clean "source of data" labels to `<prefix><two-digit year>`, for example "CR25" or "PR24"
#'
#' A label that contains a year (20, 21, ...) becomes `<prefix><year>`. The years are tried in
#' order, so the first one found wins. A label with no year is left as it is.
#' @param x Character vector of labels.
#' @param prefix "CR" or "PR".
#' @param last_year Last two-digit year to look for (use at least the report year).
recode_source <- function(x, prefix, last_year) {
  out <- as.character(x)
  done <- rep(FALSE, length(out))
  for (y in 20:last_year) {
    hit <- !done & grepl(as.character(y), x, fixed = TRUE) %in% TRUE
    out[hit] <- paste0(prefix, y)
    done <- done | hit
  }
  out
}

#' The `ActiveinYYYY` columns of the last `n` years up to the report year
#'
#' For 2025 and n = 3: Activein2023, Activein2024, Activein2025. The grants list must have them
#' (the Combiner setting `reporting: active_years` decides which ones it writes).
active_year_cols <- function(year = report_year_number, n = 3) {
  paste0("Activein", (year - n + 1):year)
}
