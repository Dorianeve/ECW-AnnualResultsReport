# Run the CR and PR checks and write the checks report.
#   Rscript scripts/run_checks.R                  # CR and PR
#   Rscript scripts/run_checks.R pr               # only some flows
# The check scripts and their Excel outputs are unchanged. Run the cleaning first.
# Report: data/output/diagnostics/checks/latest/report.md

source("scripts/prep_env.R")
cfg <- yaml::read_yaml("config.yml")

args <- commandArgs(trailingOnly = TRUE)
flows <- if (length(args)) args else c("cr", "pr")

out <- run_checks_with_diagnostics(cfg, flows = flows)
if (length(out$failures)) {
  stop("Flow(s) failed: ", paste(names(out$failures), collapse = ", "), ". See the report.", call. = FALSE)
}
