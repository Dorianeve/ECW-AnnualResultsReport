# Run the cleaning of the Combiner outputs and write the cleaning report.
#   Rscript scripts/run_cleaning.R                # CR, PR and MnE tracker
#   Rscript scripts/run_cleaning.R cr pr          # only some flows
# Report: data/output/diagnostics/cleaning/latest/report.md

source("scripts/prep_env.R")
cfg <- yaml::read_yaml("config.yml")

args <- commandArgs(trailingOnly = TRUE)
flows <- if (length(args)) args else c("cr", "pr", "mne")

out <- run_cleaning_with_diagnostics(cfg, flows = flows)
if (length(out$failures)) {
  stop("Flow(s) failed: ", paste(names(out$failures), collapse = ", "), ". See the report.", call. = FALSE)
}
