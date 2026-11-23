# Loading the project code ----
# Every file under R/ is sourced into the global environment. The legacy scripts call
# `rm(list = ls())`, which removes these functions, so `prep_env.R` (and the diagnostics runner)
# call `source_project()` again whenever they need them.

source_project <- function(root = ".") {
  files <- sort(list.files(file.path(root, "R"), pattern = "[.]R$", recursive = TRUE, full.names = TRUE))
  files <- files[basename(files) != "project.R"]
  for (f in files) source(f)
  invisible(files)
}
