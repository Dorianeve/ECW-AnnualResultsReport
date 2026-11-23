# Compare two sets of outputs ----
# "Did my change alter the results?" Compares every csv file and every sheet of every xlsx file
# in two folders, and says which are identical.
#
#   Rscript scripts/compare_outputs.R <folder A> <folder B>
#
# Typical use:
#   1. run the flow and keep the output:    copy data/output/pr/<date> and data/cleaned to a folder "before"
#   2. change the code, run the flow again
#   3. compare the new output with "before". Everything should be IDENTICAL unless you meant to change it.
#
# Only the values are compared (not colours, widths or the order of the files).

#' @param a,b The two folders. They are searched recursively.
#' @return A data frame (file, sheet, status, detail). status: IDENTICAL, DIFFERENT, ONLY_IN_A or ONLY_IN_B.
compare_output_dirs <- function(a, b) {
  list_files <- function(d) list.files(d, pattern = "[.](csv|xlsx)$", recursive = TRUE, ignore.case = TRUE)
  fa <- list_files(a); fb <- list_files(b)
  row <- function(file, sheet, status, detail = "") {
    data.frame(file = file, sheet = sheet, status = status, detail = detail, stringsAsFactors = FALSE)
  }
  same <- function(x, y) {
    r <- all.equal(x, y, check.attributes = FALSE)
    if (isTRUE(r)) row("", "", "IDENTICAL") else row("", "", "DIFFERENT", substr(paste(r, collapse = " / "), 1, 160))
  }
  out <- list()
  for (f in setdiff(fa, fb)) out[[length(out) + 1]] <- row(f, "", "ONLY_IN_A")
  for (f in setdiff(fb, fa)) out[[length(out) + 1]] <- row(f, "", "ONLY_IN_B")

  for (f in intersect(fa, fb)) {
    pa <- file.path(a, f); pb <- file.path(b, f)
    if (grepl("[.]csv$", f, ignore.case = TRUE)) {
      r <- tryCatch(same(utils::read.csv(pa, encoding = "UTF-8"), utils::read.csv(pb, encoding = "UTF-8")),
                    error = function(e) row("", "", "DIFFERENT", paste("cannot be read:", conditionMessage(e))))
      r$file <- f; out[[length(out) + 1]] <- r
    } else {
      sa <- openxlsx::getSheetNames(pa); sb <- openxlsx::getSheetNames(pb)
      for (s in setdiff(sa, sb)) out[[length(out) + 1]] <- row(f, s, "ONLY_IN_A")
      for (s in setdiff(sb, sa)) out[[length(out) + 1]] <- row(f, s, "ONLY_IN_B")
      for (s in intersect(sa, sb)) {
        r <- tryCatch(same(openxlsx::read.xlsx(pa, sheet = s), openxlsx::read.xlsx(pb, sheet = s)),
                      error = function(e) row("", "", "DIFFERENT", paste("cannot be read:", conditionMessage(e))))
        r$file <- f; r$sheet <- s; out[[length(out) + 1]] <- r
      }
    }
  }
  res <- do.call(rbind, out)
  if (is.null(res)) res <- row("", "", "IDENTICAL", "no csv or xlsx files found")[0, ]
  res[order(res$status == "IDENTICAL", res$file, res$sheet), ]
}

print_comparison <- function(res) {
  if (nrow(res) == 0) { cat("No csv or xlsx files found in the two folders.\n"); return(invisible(res)) }
  bad <- res[res$status != "IDENTICAL", ]
  for (i in seq_len(nrow(bad)))
    cat(sprintf("[%s] %s%s %s\n", bad$status[i], bad$file[i], if (nzchar(bad$sheet[i])) paste0(" / ", bad$sheet[i]) else "",
                if (nzchar(bad$detail[i])) paste0("- ", bad$detail[i]) else ""))
  cat(sprintf("\n%d identical, %d different, %d only in A, %d only in B\n", sum(res$status == "IDENTICAL"),
              sum(res$status == "DIFFERENT"), sum(res$status == "ONLY_IN_A"), sum(res$status == "ONLY_IN_B")))
  invisible(res)
}
