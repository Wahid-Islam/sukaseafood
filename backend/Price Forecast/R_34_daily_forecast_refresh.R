# =========================================================
# SukaSeafood Price Forecasting
# Step 34 — Daily Forecast Refresh Orchestrator
#
# Purpose:
#   Run the complete production forecasting pipeline from
#   the latest manually downloaded official PriceCatcher
#   dataset through database-ready forecast staging.
#
# IMPORTANT:
#   - NO web scraping is performed.
#   - PriceCatcher data must be manually downloaded and
#     placed under data/raw/.
#   - The pipeline uses the real scripts in this project.
# =========================================================


# =========================================================
# 1. LIBRARIES
# =========================================================

library(tidyverse)
library(lubridate)


# =========================================================
# 2. PROJECT DIRECTORIES
# =========================================================

project_dir <- "."

input_dir <- file.path(
  project_dir,
  "data",
  "raw"
)

processed_dir <- file.path(
  project_dir,
  "data",
  "processed"
)

lookup_dir <- file.path(
  project_dir,
  "data",
  "lookup"
)

output_dir <- file.path(
  project_dir,
  "outputs"
)

log_dir <- file.path(
  output_dir,
  "refresh_logs"
)


# =========================================================
# 3. CREATE DIRECTORIES IF REQUIRED
# =========================================================

dir.create(
  input_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  processed_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  lookup_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  log_dir,
  recursive = TRUE,
  showWarnings = FALSE
)


# =========================================================
# 4. RUN METADATA
# =========================================================

run_timestamp <- Sys.time()

run_id <- format(
  run_timestamp,
  "%Y%m%d_%H%M%S"
)

log_file <- file.path(
  log_dir,
  paste0(
    "forecast_refresh_",
    run_id,
    ".log"
  )
)


# =========================================================
# 5. LOGGING FUNCTION
# =========================================================

log_message <- function(...) {
  
  message_text <- paste0(...)
  
  timestamped <- paste0(
    "[",
    format(
      Sys.time(),
      "%Y-%m-%d %H:%M:%S"
    ),
    "] ",
    message_text
  )
  
  cat(
    timestamped,
    "\n"
  )
  
  cat(
    timestamped,
    "\n",
    file = log_file,
    append = TRUE
  )
  
}


# =========================================================
# 6. START LOG
# =========================================================

log_message(
  "========================================"
)

log_message(
  "SukaSeafood forecast refresh started"
)

log_message(
  "Run ID: ",
  run_id
)

log_message(
  "Scraping used: FALSE"
)


# =========================================================
# 7. VALIDATE REQUIRED INPUT STRUCTURE
# =========================================================

mapping_file <- file.path(
  lookup_dir,
  "price_forecast_fish_mapping.csv"
)

if (
  !file.exists(
    mapping_file
  )
) {
  
  stop(
    paste0(
      "Fish mapping file not found: ",
      mapping_file
    )
  )
  
}

log_message(
  "Fish mapping found: ",
  mapping_file
)


# =========================================================
# 8. DETECT PRICECATCHER INPUT FILES
#
# The official PriceCatcher files are manually downloaded.
# We do not scrape or download anything here.
# =========================================================

candidate_files <- list.files(
  
  path = input_dir,
  
  pattern = "\\.csv$",
  
  full.names = TRUE,
  
  recursive = TRUE,
  
  ignore.case = TRUE
  
)


if (
  length(
    candidate_files
  ) == 0
) {
  
  stop(
    paste0(
      "No PriceCatcher CSV files were found under ",
      input_dir,
      ". ",
      "Download the latest official PriceCatcher release ",
      "manually and place it under data/raw/."
    )
  )
  
}


# =========================================================
# 9. INPUT FILE METADATA
# =========================================================

file_info <- file.info(
  candidate_files
) %>%
  
  tibble::rownames_to_column(
    "file_path"
  ) %>%
  
  filter(
    !is.na(size),
    size > 0
  ) %>%
  
  arrange(
    desc(mtime)
  )


if (
  nrow(
    file_info
  ) == 0
) {
  
  stop(
    "PriceCatcher CSV files were found, but none are readable/non-empty."
  )
  
}


latest_raw_file <- file_info$file_path[1]

latest_raw_size_mb <-
  file_info$size[1] /
  1024^2


log_message(
  "PriceCatcher CSV files detected: ",
  nrow(
    file_info
  )
)

log_message(
  "Latest modified PriceCatcher file: ",
  latest_raw_file
)

log_message(
  "Latest file size: ",
  round(
    latest_raw_size_mb,
    2
  ),
  " MB"
)


# =========================================================
# 10. REPORT THE RAW DATA RANGE
#
# We do not assume a specific filename format.
# The actual preparation step remains responsible for
# parsing the PriceCatcher source files.
# =========================================================

log_message(
  "Raw PriceCatcher input validation passed."
)


# =========================================================
# 11. DEFINE PRODUCTION PIPELINE
#
# These are the ACTUAL scripts in this project.
# =========================================================

pipeline_scripts <- c(
  
  "R:23 multi_fish_price_series.R",
  
  "R:27_multi_fish_cleaning.R",
  
  "R:28_multi_fish_ets_backtest.R",
  
  "R:29.1_final_forecast_eligibility.R",
  
  "R:30_production_forecast.R",
  
  "R:31_direction_outlook_validation.R",
  
  "R:32_integrate_production_forecast.R",
  
  "R:33A_create_database_forecast_staging.R"
  
)


# =========================================================
# 12. ACTUAL SCRIPT PATHS
# =========================================================

script_dir <- file.path(
  project_dir,
  "R"
)


pipeline_paths <- file.path(
  script_dir,
  pipeline_scripts
)


missing_scripts <- pipeline_scripts[
  
  !file.exists(
    pipeline_paths
  )
  
]


if (
  length(
    missing_scripts
  ) > 0
) {
  
  log_message(
    "Required pipeline scripts missing:"
  )
  
  for (
    script_name in
    missing_scripts
  ) {
    
    log_message(
      "  - ",
      script_name
    )
    
  }
  
  stop(
    "Pipeline cannot start because one or more required scripts are missing."
  )
  
}


log_message(
  "All production pipeline scripts found."
)


# =========================================================
# 13. PIPELINE RESULT TABLE
# =========================================================

pipeline_results <- vector(
  mode = "list",
  length = 0
)


# =========================================================
# 14. RUN PIPELINE
# =========================================================

pipeline_failed <- FALSE

pipeline_failure_message <- NULL


for (
  i in seq_along(
    pipeline_scripts
  )
) {
  
  script_name <-
    pipeline_scripts[i]
  
  script_path <-
    pipeline_paths[i]
  
  step_start <-
    Sys.time()
  
  log_message(
    ""
  )
  
  log_message(
    "----------------------------------------"
  )
  
  log_message(
    "Running step ",
    i,
    " / ",
    length(
      pipeline_scripts
    ),
    ": ",
    script_name
  )
  
  step_status <-
    "SUCCESS"
  
  step_error <-
    NA_character_
  
  
  tryCatch(
    
    {
      
      source(
        script_path,
        local = FALSE
      )
      
    },
    
    error = function(e) {
      
      step_status <<-
        "FAILED"
      
      step_error <<-
        conditionMessage(
          e
        )
      
    }
    
  )
  
  
  step_finish <-
    Sys.time()
  
  
  elapsed <-
    as.numeric(
      difftime(
        step_finish,
        step_start,
        units = "secs"
      )
    )
  
  
  pipeline_results[[
    length(
      pipeline_results
    ) + 1
  ]] <-
    tibble(
      
      step =
        i,
      
      script =
        script_name,
      
      status =
        step_status,
      
      started_at =
        step_start,
      
      finished_at =
        step_finish,
      
      elapsed_seconds =
        elapsed,
      
      error_message =
        step_error
      
    )
  
  
  if (
    step_status ==
    "FAILED"
  ) {
    
    pipeline_failed <-
      TRUE
    
    pipeline_failure_message <-
      paste0(
        "Pipeline failed at ",
        script_name,
        ": ",
        step_error
      )
    
    log_message(
      "FAILED: ",
      script_name
    )
    
    log_message(
      "Error: ",
      step_error
    )
    
    break
    
  }
  
  
  log_message(
    "Completed successfully in ",
    round(
      elapsed,
      2
    ),
    " seconds."
  )
  
}


# =========================================================
# 15. SAVE STEP LOG
# =========================================================

pipeline_results_df <-
  bind_rows(
    pipeline_results
  )


pipeline_log_file <- file.path(
  log_dir,
  paste0(
    "forecast_refresh_steps_",
    run_id,
    ".csv"
  )
)


write_csv(
  pipeline_results_df,
  pipeline_log_file
)


# =========================================================
# 16. STOP IMMEDIATELY IF PIPELINE FAILED
# =========================================================

if (
  pipeline_failed
) {
  
  log_message(
    "========================================"
  )
  
  log_message(
    "FORECAST REFRESH FAILED"
  )
  
  log_message(
    "========================================"
  )
  
  log_message(
    pipeline_failure_message
  )
  
  stop(
    pipeline_failure_message
  )
  
}


# =========================================================
# 17. REQUIRED PRODUCTION OUTPUTS
# =========================================================

required_outputs <- c(
  
  "production_forecast_api.csv",
  
  "production_forecast_with_direction.csv",
  
  "production_current_direction.csv",
  
  "db_price_forecast_staging.csv",
  
  "db_forecast_model_version_staging.csv",
  
  "db_forecast_lookup_contract.csv",
  
  "db_forecast_column_mapping.csv",
  
  "db_forecast_staging_summary.csv"
  
)


missing_outputs <- required_outputs[
  
  !file.exists(
    file.path(
      output_dir,
      required_outputs
    )
  )
  
]


if (
  length(
    missing_outputs
  ) > 0
) {
  
  log_message(
    "Required production outputs are missing:"
  )
  
  for (
    output_name in
    missing_outputs
  ) {
    
    log_message(
      "  - ",
      output_name
    )
    
  }
  
  stop(
    "Pipeline completed, but required production outputs are missing."
  )
  
}


log_message(
  "All required production outputs exist."
)


# =========================================================
# 18. LOAD API FORECAST
# =========================================================

api_file <- file.path(
  output_dir,
  "production_forecast_api.csv"
)


api_forecast <- read_csv(
  
  api_file,
  
  show_col_types =
    FALSE
  
) %>%
  
  mutate(
    
    reference_week =
      as.Date(
        reference_week
      ),
    
    forecast_week =
      as.Date(
        forecast_week
      )
    
  ) %>%
  
  arrange(
    
    canonical_name,
    
    forecast_week
    
  )


# =========================================================
# 19. API SCHEMA VALIDATION
#
# IMPORTANT:
#   production_forecast_api.csv intentionally contains
#   outlook_label and directional_outlook_label rather than
#   the raw categorical `outlook` field.
# =========================================================

required_api_columns <- c(
  
  "forecast_id",
  
  "canonical_name",
  
  "location",
  
  "forecast_week",
  
  "reference_week",
  
  "reference_price",
  
  "expected_price",
  
  "lower_bound",
  
  "upper_bound",
  
  "outlook_label",
  
  "directional_outlook_label",
  
  "model_used",
  
  "quality_status",
  
  "generated_at",
  
  "model_version"
  
)


missing_api_columns <- setdiff(
  
  required_api_columns,
  
  names(
    api_forecast
  )
  
)


if (
  length(
    missing_api_columns
  ) > 0
) {
  
  stop(
    paste(
      "Production API file is missing required columns:",
      paste(
        missing_api_columns,
        collapse = ", "
      )
    )
  )
  
}


log_message(
  "API schema validation passed."
)


# =========================================================
# 20. FORECAST SIZE VALIDATION
# =========================================================

fish_count <-
  n_distinct(
    api_forecast$canonical_name
  )


row_count <-
  nrow(
    api_forecast
  )


expected_rows <-
  fish_count *
  4


log_message(
  "Forecastable fish: ",
  fish_count
)


log_message(
  "Forecast rows: ",
  row_count
)


if (
  row_count !=
  expected_rows
) {
  
  stop(
    paste(
      "Unexpected forecast row count.",
      "Expected:",
      expected_rows,
      "Found:",
      row_count
    )
  )
  
}


# =========================================================
# 21. EXACTLY FOUR WEEKS PER FISH
# =========================================================

forecast_counts <-
  api_forecast %>%
  
  count(
    canonical_name
  ) %>%
  
  filter(
    n != 4
  )


if (
  nrow(
    forecast_counts
  ) > 0
) {
  
  print(
    forecast_counts,
    n = Inf
  )
  
  stop(
    "One or more fish do not have exactly four forecast weeks."
  )
  
}


# =========================================================
# 22. FORECAST RANGE VALIDATION
# =========================================================

range_errors <-
  api_forecast %>%
  
  filter(
    
    lower_bound >
      upper_bound |
      
      expected_price <
      lower_bound |
      
      expected_price >
      upper_bound |
      
      lower_bound <
      0 |
      
      expected_price <=
      0
    
  )


if (
  nrow(
    range_errors
  ) > 0
) {
  
  print(
    range_errors,
    n = Inf
  )
  
  stop(
    "Invalid forecast ranges found."
  )
  
}


# =========================================================
# 23. QUALITY STATUS VALIDATION
# =========================================================

valid_quality_status <- c(
  
  "VALID",
  
  "SPARSE_DATA"
  
)


invalid_quality <-
  api_forecast %>%
  
  filter(
    
    is.na(
      quality_status
    ) |
      
      !quality_status %in%
      valid_quality_status
    
  )


if (
  nrow(
    invalid_quality
  ) > 0
) {
  
  print(
    invalid_quality,
    n = Inf
  )
  
  stop(
    "Invalid quality_status detected."
  )
  
}


# =========================================================
# 24. MODEL VALIDATION
# =========================================================

valid_models <- c(
  
  "ETS(A,N,N)",
  
  "NAIVE"
  
)


invalid_models <-
  api_forecast %>%
  
  filter(
    
    is.na(
      model_used
    ) |
      
      !model_used %in%
      valid_models
    
  )


if (
  nrow(
    invalid_models
  ) > 0
) {
  
  print(
    invalid_models,
    n = Inf
  )
  
  stop(
    "Invalid model_used value detected."
  )
  
}


# =========================================================
# 25. OUTLOOK LABEL VALIDATION
# =========================================================

valid_outlook_labels <- c(
  
  "Around current levels",
  
  "Likely to increase",
  
  "Likely to decrease"
  
)


invalid_outlook_labels <-
  api_forecast %>%
  
  filter(
    
    is.na(
      outlook_label
    ) |
      
      !outlook_label %in%
      valid_outlook_labels
    
  )


if (
  nrow(
    invalid_outlook_labels
  ) > 0
) {
  
  print(
    invalid_outlook_labels,
    n = Inf
  )
  
  stop(
    "Invalid outlook_label detected."
  )
  
}


# =========================================================
# 26. DIRECTIONAL OUTLOOK LABEL VALIDATION
# =========================================================

valid_directional_outlook_labels <- c(
  
  "Likely to increase",
  
  "Likely to decrease",
  
  "No strong directional signal"
  
)


invalid_directional_outlook <-
  api_forecast %>%
  
  filter(
    
    is.na(
      directional_outlook_label
    ) |
      
      !directional_outlook_label %in%
      valid_directional_outlook_labels
    
  )


if (
  nrow(
    invalid_directional_outlook
  ) > 0
) {
  
  print(
    invalid_directional_outlook,
    n = Inf
  )
  
  stop(
    "Invalid directional_outlook_label detected."
  )
  
}


# =========================================================
# 27. FORECAST HORIZON VALIDATION
# =========================================================

reference_week <-
  max(
    api_forecast$reference_week,
    na.rm = TRUE
  )


expected_forecast_weeks <-
  as.Date(
    
    seq(
      
      from =
        reference_week +
        weeks(1),
      
      by =
        "1 week",
      
      length.out =
        4
      
    )
    
  )


actual_forecast_weeks <-
  sort(
    
    unique(
      api_forecast$forecast_week
    )
    
  )


if (
  !all(
    expected_forecast_weeks %in%
    actual_forecast_weeks
  ) ||
  
  !all(
    actual_forecast_weeks %in%
    expected_forecast_weeks
  )
) {
  
  log_message(
    "Expected forecast weeks:"
  )
  
  print(
    expected_forecast_weeks
  )
  
  log_message(
    "Actual forecast weeks:"
  )
  
  print(
    actual_forecast_weeks
  )
  
  stop(
    "Forecast horizon validation failed."
  )
  
}


# =========================================================
# 28. SOURCE DATA DATE VALIDATION
# =========================================================

daily_file <- file.path(
  
  processed_dir,
  
  "multi_fish_selangor_daily.csv"
  
)


source_latest_date <-
  as.Date(
    NA
  )


if (
  file.exists(
    daily_file
  )
) {
  
  daily_refresh <-
    read_csv(
      
      daily_file,
      
      show_col_types =
        FALSE
      
    ) %>%
    
    mutate(
      
      date =
        as.Date(
          date
        )
      
    )
  
  
  if (
    nrow(
      daily_refresh
    ) > 0
  ) {
    
    source_latest_date <-
      max(
        daily_refresh$date,
        na.rm = TRUE
      )
    
  }
  
}


if (
  is.na(
    source_latest_date
  )
) {
  
  stop(
    "Could not determine latest source observation date from processed daily data."
  )
  
}


log_message(
  "Latest processed source date: ",
  source_latest_date
)


# =========================================================
# 29. SOURCE DATA SANITY CHECK
# =========================================================

if (
  source_latest_date <
  as.Date(
    "2026-08-01"
  )
) {
  
  stop(
    paste(
      "Latest processed source date appears stale:",
      source_latest_date
    )
  )
  
}


# =========================================================
# 30. PRODUCTION REFERENCE WEEK
# =========================================================

expected_reference_week <-
  floor_date(
    
    source_latest_date,
    
    unit =
      "week",
    
    week_start =
      1
    
  ) -
  
  weeks(1)


if (
  reference_week !=
  expected_reference_week
) {
  
  log_message(
    "Expected reference week: ",
    expected_reference_week
  )
  
  log_message(
    "Actual reference week: ",
    reference_week
  )
  
  stop(
    "Reference week does not match the latest completed source week."
  )
  
}


# =========================================================
# 31. DATABASE STAGING VALIDATION
# =========================================================

staging_file <- file.path(
  
  output_dir,
  
  "db_price_forecast_staging.csv"
  
)


staging <- read_csv(
  
  staging_file,
  
  show_col_types =
    FALSE
  
)


required_staging_columns <- c(
  
  "forecast_id",
  
  "canonical_name",
  
  "location_name",
  
  "model_version_name",
  
  "model_algorithm",
  
  "forecast_engine_version",
  
  "forecast_origin_date",
  
  "forecast_week_start",
  
  "horizon_weeks",
  
  "current_reference_price",
  
  "expected_price",
  
  "lower_bound",
  
  "upper_bound",
  
  "outlook",
  
  "directional_outlook_label",
  
  "quality_status",
  
  "generated_at"
  
)


missing_staging_columns <- setdiff(
  
  required_staging_columns,
  
  names(
    staging
  )
  
)


if (
  length(
    missing_staging_columns
  ) > 0
) {
  
  stop(
    paste(
      "Database staging file is missing columns:",
      paste(
        missing_staging_columns,
        collapse = ", "
      )
    )
  )
  
}


# =========================================================
# 32. DATABASE STAGING ROW VALIDATION
# =========================================================

staging_row_count <-
  nrow(
    staging
  )


if (
  staging_row_count !=
  row_count
) {
  
  stop(
    paste(
      "Database staging row count mismatch.",
      "API rows:",
      row_count,
      "Staging rows:",
      staging_row_count
    )
  )
  
}


staging_fish_count <-
  n_distinct(
    staging$canonical_name
  )


if (
  staging_fish_count !=
  fish_count
) {
  
  stop(
    paste(
      "Database staging fish count mismatch.",
      "Expected:",
      fish_count,
      "Found:",
      staging_fish_count
    )
  )
  
}


# =========================================================
# 33. STAGING DUPLICATE VALIDATION
# =========================================================

duplicate_keys <-
  staging %>%
  
  count(
    
    canonical_name,
    
    location_name,
    
    model_version_name,
    
    forecast_week_start
    
  ) %>%
  
  filter(
    n > 1
  )


if (
  nrow(
    duplicate_keys
  ) > 0
) {
  
  print(
    duplicate_keys,
    n = Inf
  )
  
  stop(
    "Duplicate database forecast natural keys detected."
  )
  
}


# =========================================================
# 34. MASTER FISH MAPPING VALIDATION
# =========================================================

fish_mapping <-
  read_csv(
    
    mapping_file,
    
    show_col_types =
      FALSE
    
  )


if (
  !"canonical_name" %in%
  names(
    fish_mapping
  )
) {
  
  stop(
    "Fish mapping file does not contain canonical_name."
  )
  
}


mapping_names <-
  fish_mapping %>%
  
  distinct(
    canonical_name
  )


missing_mapping_fish <-
  api_forecast %>%
  
  distinct(
    canonical_name
  ) %>%
  
  anti_join(
    mapping_names,
    by =
      "canonical_name"
  )


if (
  nrow(
    missing_mapping_fish
  ) > 0
) {
  
  print(
    missing_mapping_fish,
    n = Inf
  )
  
  stop(
    "One or more forecast fish are missing from the master fish mapping."
  )
  
}


# =========================================================
# 35. BUILD RUN MANIFEST
# =========================================================

run_manifest <- tibble(
  
  run_id =
    run_id,
  
  run_started_at =
    run_timestamp,
  
  run_completed_at =
    Sys.time(),
  
  source_latest_date =
    source_latest_date,
  
  reference_week =
    reference_week,
  
  first_forecast_week =
    min(
      api_forecast$forecast_week
    ),
  
  last_forecast_week =
    max(
      api_forecast$forecast_week
    ),
  
  forecastable_fish =
    fish_count,
  
  forecast_rows =
    row_count,
  
  database_staging_rows =
    staging_row_count,
  
  pipeline_status =
    "SUCCESS",
  
  scraping_used =
    FALSE,
  
  model_engine =
    "MODEL_SELECTION_V1",
  
  model_version =
    paste(
      unique(
        api_forecast$model_version
      ),
      collapse =
        ", "
    )
  
)


# =========================================================
# 36. SAVE RUN MANIFEST
# =========================================================

run_manifest_file <- file.path(
  
  log_dir,
  
  paste0(
    "forecast_refresh_manifest_",
    run_id,
    ".csv"
  )
  
)


write_csv(
  
  run_manifest,
  
  run_manifest_file
  
)


# =========================================================
# 37. FINAL PIPELINE LOG
# =========================================================

log_message(
  ""
)

log_message(
  "========================================"
)

log_message(
  "FORECAST REFRESH SUCCESSFUL"
)

log_message(
  "========================================"
)

log_message(
  "Run ID: ",
  run_id
)

log_message(
  "Latest source date: ",
  source_latest_date
)

log_message(
  "Reference week: ",
  reference_week
)

log_message(
  "Forecastable fish: ",
  fish_count
)

log_message(
  "Forecast rows: ",
  row_count
)

log_message(
  "Forecast horizon: ",
  min(
    api_forecast$forecast_week
  ),
  " -> ",
  max(
    api_forecast$forecast_week
  )
)

log_message(
  "Database staging rows: ",
  staging_row_count
)

log_message(
  "Scraping used: FALSE"
)

log_message(
  "API forecast: ",
  api_file
)

log_message(
  "Database staging: ",
  staging_file
)

log_message(
  "Run manifest: ",
  run_manifest_file
)

log_message(
  "Pipeline step log: ",
  pipeline_log_file
)

log_message(
  ""
)

log_message(
  "Production forecast is ready for backend ingestion."
)

