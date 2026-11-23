# Compare two folders of outputs (csv and xlsx), file by file and sheet by sheet.
#   Rscript scripts/compare_outputs.R "data/output/pr/2026-10-12" "backup/pr/2026-10-12"
# Use it after every change of the code: the results must be IDENTICAL unless you meant to change them.
# The exit status is 1 if anything is different.

source("R/pipeline/project.R")
source_project()

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("Give two folders: Rscript scripts/compare_outputs.R <folder A> <folder B>", call. = FALSE)

res <- print_comparison(compare_output_dirs(args[1], args[2]))
if (any(res$status != "IDENTICAL")) quit(status = 1)
