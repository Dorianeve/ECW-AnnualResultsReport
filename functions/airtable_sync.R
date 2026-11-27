# Airtable sync: pull a table's records into a data frame (fetch_airtable +
# airtable_records_to_df), and push a data frame back by upsert (push_to_airtable).
# Used by scripts/airtable/ingest_from_airtable.R and scripts/airtable/load_checks.R.
#
# The API token is a secret: it is never read from config.yml. Set AIRTABLE_TOKEN in
# .Renviron (see .Renviron.example) and restart R. The base id and table name are not
# secrets and live in config.yml under `airtable:`.

airtable_url <- function(base_id, table_name) {
  paste0("https://api.airtable.com/v0/", base_id, "/", utils::URLencode(table_name, reserved = TRUE))
}

airtable_headers <- function(token) {
  httr::add_headers(Authorization = paste("Bearer", token), `Content-Type` = "application/json")
}

airtable_stop_for_status <- function(resp, what) {
  if (httr::status_code(resp) >= 400) {
    stop("Airtable ", what, " failed (HTTP ", httr::status_code(resp), "): ",
         httr::content(resp, as = "text", encoding = "UTF-8"))
  }
}

# Pull every record of an Airtable table (handles pagination). Returns a list of records
# (each with $id, $createdTime, $fields), as parsed by jsonlite with simplifyVector = FALSE.
fetch_airtable <- function(token, base_id, table_name, sleep = 0.25) {
  stopifnot(nchar(base_id) > 0, nchar(token) > 0, nchar(table_name) > 0)

  url     <- airtable_url(base_id, table_name)
  headers <- airtable_headers(token)

  all_records <- list()
  offset <- NULL

  repeat {
    query <- if (!is.null(offset)) list(offset = offset) else list()
    resp  <- httr::GET(url, headers, query = query)
    airtable_stop_for_status(resp, "GET")

    parsed <- jsonlite::fromJSON(
      httr::content(resp, as = "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    )

    all_records <- c(all_records, parsed$records)
    message("Fetched ", length(all_records), " records so far...")

    offset <- parsed$offset
    if (is.null(offset)) break
    Sys.sleep(sleep)
  }

  message("Done. Total records: ", length(all_records))
  all_records
}

# Convert the list of records returned by fetch_airtable() to a data frame (one row per
# record, one column per field; missing fields are filled with NA).
airtable_records_to_df <- function(records) {
  if (length(records) == 0) {
    message("No records found.")
    return(data.frame())
  }

  rows <- lapply(records, function(rec) {
    fields <- rec$fields
    fields[["airtable_id"]]  <- rec$id
    fields[["created_time"]] <- rec$createdTime
    as.data.frame(fields, stringsAsFactors = FALSE, check.names = FALSE)
  })

  all_cols <- unique(unlist(lapply(rows, names)))
  rows <- lapply(rows, function(r) {
    missing <- setdiff(all_cols, names(r))
    r[missing] <- NA
    r[all_cols]
  })

  do.call(rbind, rows)
}

# Push a data frame to Airtable, creating or updating records by upsert: a row whose
# `merge_on` columns match an existing record updates it, otherwise a new record is created.
#
# @param merge_on Column names that identify a record. Must be columns of `df` and fields
#   of the Airtable table (Airtable does the matching, not this function).
push_to_airtable <- function(df, token, base_id, table_name, merge_on, batch_size = 10, sleep = 0.25) {
  if (nrow(df) == 0) {
    message("Nothing to push to Airtable (", table_name, "): the data frame is empty.")
    return(invisible(df))
  }
  stopifnot(nchar(base_id) > 0, nchar(token) > 0, nchar(table_name) > 0)

  missing <- setdiff(merge_on, names(df))
  if (length(missing) > 0)
    stop("push_to_airtable: merge_on column(s) not in df: ", paste(missing, collapse = ", "))

  url     <- airtable_url(base_id, table_name)
  headers <- airtable_headers(token)

  # One Airtable record per row; NA / empty values are left out (Airtable keeps the field blank)
  row_to_fields <- function(row) {
    fields <- as.list(row)
    keep   <- !vapply(fields, function(x) is.na(x) || identical(x, ""), logical(1))
    fields[keep]
  }
  records <- lapply(seq_len(nrow(df)), function(i) list(fields = row_to_fields(df[i, ])))

  n_batches <- ceiling(length(records) / batch_size)
  for (b in seq_len(n_batches)) {
    idx  <- seq((b - 1) * batch_size + 1, min(b * batch_size, length(records)))
    body <- list(performUpsert = list(fieldsToMergeOn = as.list(merge_on)),
                 records = records[idx], typecast = TRUE)

    resp <- httr::PATCH(url, headers, body = body, encode = "json")
    airtable_stop_for_status(resp, "PATCH")
    message("Pushed batch ", b, "/", n_batches, " (", length(idx), " records) to Airtable: ", table_name)
    if (b < n_batches) Sys.sleep(sleep)
  }

  invisible(df)
}
