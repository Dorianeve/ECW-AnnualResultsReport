# Optional Google Drive API sync (only needed if Drive for Desktop is NOT used).
# Enable with `gdrive: enabled: true` and folder IDs in config.yml.
# With Drive for Desktop just point `mne_approval` to the Drive path, or copy files into data/input/.

gdrive_download_inputs <- function(folder_id, dest = "data/input") {
  if (!requireNamespace("googledrive", quietly = TRUE)) install.packages("googledrive")
  googledrive::drive_auth()
  files <- googledrive::drive_ls(googledrive::as_id(folder_id))
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  for (i in seq_len(nrow(files))) {
    googledrive::drive_download(files[i, ], path = file.path(dest, files$name[i]), overwrite = TRUE)
  }
  invisible(files$name)
}

gdrive_upload_outputs <- function(folder_id, local_dir) {
  if (!requireNamespace("googledrive", quietly = TRUE)) install.packages("googledrive")
  googledrive::drive_auth()
  for (f in list.files(local_dir, recursive = TRUE, full.names = TRUE)) {
    googledrive::drive_upload(f, path = googledrive::as_id(folder_id), overwrite = TRUE)
  }
  invisible(TRUE)
}
