# Check the settings, the input files and the code BEFORE a run.
#   Rscript scripts/check_setup.R
# Prints one line for each check (OK / WARN / FAIL) and what to do about it.
# The exit status is 1 if there is a FAIL, so it can also be used in a script.

source("R/pipeline/project.R")
source_project()

res <- print_setup_check(setup_check("."))
if (any(res$status == "FAIL")) quit(status = 1)
