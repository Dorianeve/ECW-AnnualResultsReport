# Prepare the environment: functions, libraries and parameters from config.yml.
# Run all scripts from the project root (open AnnualResultsReport.Rproj).

if (!isTRUE(getOption("arr.debug"))) rm(list = ls())

if (!file.exists("config.yml")) {
  stop("config.yml not found in ", getwd(),
       ". Run from the project root and copy config.example.yml to config.yml.")
}

# load necessary libraries
source("requirements/libraries.R")

# load the project code under R/ (diagnostics, trace helpers)
source("R/pipeline/project.R")
source_project()

# load custom functions in functions folder
for (f in list.files("functions", pattern = "[.]R$", full.names = TRUE)) source(f)
for (f in list.files("functions/analysis_cr", pattern = "[.]R$", full.names = TRUE)) source(f)

# load parameters from config.yml as variables in the global environment
cfg <- yaml::read_yaml("config.yml")
list2env(cfg, envir = globalenv())

# resolve input file locations: relative paths live in data/input/
is_absolute <- function(p) grepl("^([A-Za-z]:|/|~|[\\][\\])", p)
if (!is_absolute(mne_approval)) mne_approval <- file.path("data", "input", mne_approval)

rm(f, cfg)

# optional Google Drive API sync of the inputs
# (once per R session: every script sources this file, and `.gdrive_synced` survives `rm(list = ls())`)
if (isTRUE(gdrive$enabled) && nzchar(gdrive$input_folder_id) && !exists(".gdrive_synced", envir = globalenv())) {
  gdrive_download_inputs(gdrive$input_folder_id)
  assign(".gdrive_synced", TRUE, envir = globalenv())
}
