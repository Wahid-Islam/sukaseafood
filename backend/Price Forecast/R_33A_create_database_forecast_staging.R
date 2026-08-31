# =========================================================
# SukaSeafood Price Forecasting
# Step 33A — Create Database Forecast Staging Package
# =========================================================
#
# Purpose:
#
#   Convert the production forecasting output into a
#   database-ingestion package aligned with the SukaSeafood
#   V3 schema.
#
# IMPORTANT:
#
#   This script DOES NOT insert directly into PostgreSQL.
#
#   It produces staging CSVs for the backend/database
#   developer.
#
#   The backend is responsible for resolving:
#
#     canonical_name
#         -> seafood_item_id
#
#     "Selangor"
#         -> location_id
#
#     model_version_name
#         -> forecast_model_version_id
#
#     source snapshot
#         -> source_snapshot_id
#
#   This preserves the schema's canonical-ID architecture.
#
# =========================================================

library(tidyverse)
library(lubridate)

output_dir <- "outputs"
lookup_dir <- "data/lookup"

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# =========================================================
# 1. LOAD PRODUCTION FORECAST
# =========================================================

forecast_file <- file.path(
  output_dir,
  "production_forecast_with_direction.csv"
)

if (
  !file.exists(
    forecast_file
  )
) {
  
  stop(
    paste(
      "Production forecast not found:",
      forecast_file
    )
  )
  
}

forecast <- read_csv(
  forecast_file,
  show_col_types = FALSE
) %>%
  mutate(
    
    reference_week =
      as.Date(
        reference_week
      ),
    
    forecast_week =
      as.Date(
        forecast_week
      ),
    
    generated_at =
      as.POSIXct(
        generated_at,
        tz = "UTC"
      )
    
  ) %>%
  arrange(
    canonical_name,
    forecast_week
  )

# =========================================================
# 2. LOAD FISH MAPPING
# =========================================================
#
# The mapping is used for validation only.
#
# The database's seafood_item_id remains the canonical
# identity. We do NOT create a replacement ID here.
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
    paste(
      "Fish mapping file not found:",
      mapping_file
    )
  )
  
}

fish_mapping <- read_csv(
  mapping_file,
  show_col_types = FALSE
)

if (
  !"canonical_name" %in%
  names(
    fish_mapping
  )
) {
  
  stop(
    "Fish mapping must contain canonical_name."
  )
  
}

# =========================================================
# 3. VALIDATE CANONICAL NAMES
# =========================================================

mapping_fish <-
  fish_mapping %>%
  distinct(
    canonical_name
  )

forecast_fish <-
  forecast %>%
  distinct(
    canonical_name
  )

missing_from_mapping <-
  forecast_fish %>%
  anti_join(
    mapping_fish,
    by =
      "canonical_name"
  )

if (
  nrow(
    missing_from_mapping
  ) > 0
) {
  
  print(
    missing_from_mapping,
    n = Inf
  )
  
  stop(
    "One or more forecast fish are missing from the fish mapping."
  )
  
}

# =========================================================
# 4. VALIDATE FORECAST STRUCTURE
# =========================================================

required_forecast_columns <- c(
  
  "canonical_name",
  
  "location",
  
  "reference_week",
  
  "reference_price",
  
  "forecast_week",
  
  "expected_price",
  
  "lower_bound",
  
  "upper_bound",
  
  "outlook",
  
  "outlook_label",
  
  "directional_outlook",
  
  "directional_outlook_label",
  
  "model_used",
  
  "quality_status",
  
  "generated_at",
  
  "model_version"
  
)

missing_columns <-
  setdiff(
    required_forecast_columns,
    names(
      forecast
    )
  )

if (
  length(
    missing_columns
  ) > 0
) {
  
  stop(
    paste(
      "Missing required forecast columns:",
      paste(
        missing_columns,
        collapse = ", "
      )
    )
  )
  
}

# =========================================================
# 5. VALIDATE FOUR FORECAST WEEKS PER FISH
# =========================================================

forecast_counts <-
  forecast %>%
  count(
    canonical_name
  )

invalid_counts <-
  forecast_counts %>%
  filter(
    n != 4
  )

if (
  nrow(
    invalid_counts
  ) > 0
) {
  
  print(
    invalid_counts,
    n = Inf
  )
  
  stop(
    "Every forecastable fish must have exactly four forecast weeks."
  )
  
}

# =========================================================
# 6. VALIDATE FORECAST ORDER
# =========================================================

forecast_order_check <-
  forecast %>%
  
  group_by(
    canonical_name
  ) %>%
  
  summarise(
    
    reference_week =
      first(
        reference_week
      ),
    
    first_forecast_week =
      min(
        forecast_week
      ),
    
    .groups =
      "drop"
    
  ) %>%
  
  mutate(
    
    expected_first_forecast =
      reference_week +
      weeks(1)
    
  )

invalid_order <-
  forecast_order_check %>%
  filter(
    
    first_forecast_week !=
      expected_first_forecast
    
  )

if (
  nrow(
    invalid_order
  ) > 0
) {
  
  print(
    invalid_order,
    n = Inf
  )
  
  stop(
    "Forecast weeks do not begin one week after the reference week."
  )
  
}

# =========================================================
# 7. CREATE HORIZON WEEK
# =========================================================
#
# horizon_weeks is required by price_forecast.
#
# 1 = next week
# 2 = two weeks ahead
# 3 = three weeks ahead
# 4 = four weeks ahead
# =========================================================

forecast <- forecast %>%
  
  group_by(
    canonical_name
  ) %>%
  
  arrange(
    forecast_week,
    .by_group = TRUE
  ) %>%
  
  mutate(
    
    horizon_weeks =
      row_number()
    
  ) %>%
  
  ungroup()

# =========================================================
# 8. SET MODEL VERSION STRATEGY
# =========================================================
#
# We currently have two forecasting algorithms:
#
#   ETS(A,N,N)
#   NAIVE
#
# However, the deployed system is not "ETS only".
#
# The production forecasting engine uses a validated model
# selection policy that chooses ETS or NAIVE per fish.
#
# Therefore we represent the deployed production policy as
# one model version:
#
#   MODEL_SELECTION_V1
#
# The exact algorithm used for each fish remains recorded
# in price_forecast.model_used.
#
# =========================================================

forecast <- forecast %>%
  mutate(
    
    forecast_engine_version =
      model_version,
    
    forecast_model_version_name =
      paste0(
        "SukaSeafood Price Forecast Model Selection ",
        model_version
      ),
    
    forecast_algorithm =
      "MODEL_SELECTION_V1"
    
  )

# =========================================================
# 9. VALIDATE MODEL TYPES
# =========================================================

valid_models <- c(
  
  "ETS(A,N,N)",
  
  "NAIVE"
  
)

invalid_models <-
  forecast %>%
  filter(
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
    "Unexpected model_used value detected."
  )
  
}

# =========================================================
# 10. VALIDATE QUALITY STATUS
# =========================================================

valid_quality <- c(
  
  "VALID",
  
  "SPARSE_DATA"
  
)

invalid_quality <-
  forecast %>%
  filter(
    !quality_status %in%
      valid_quality
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
    "Unexpected quality_status detected."
  )
  
}

# =========================================================
# 11. CREATE MODEL VERSION STAGING ROW
# =========================================================
#
# This corresponds to:
#
#   forecast_model_version
#
# The real UUID will be generated/resolved by the database
# layer.
# =========================================================

model_version_staging <- forecast %>%
  
  distinct(
    
    forecast_model_version_name,
    
    forecast_algorithm,
    
    forecast_engine_version
    
  ) %>%
  
  mutate(
    
    algorithm =
      forecast_algorithm,
    
    target_definition =
      "One-week-ahead to four-week-ahead weekly seafood price outlook using validated per-fish model selection.",
    
    training_start_date =
      as.Date(
        "2025-01-06"
      ),
    
    training_end_date =
      max(
        forecast$reference_week,
        na.rm = TRUE
      ),
    
    validation_mae =
      NA_real_,
    
    validation_rmse =
      NA_real_,
    
    validation_mape =
      NA_real_,
    
    validation_interval_level =
      0.80,
    
    configuration =
      paste0(
        
        '{"direction_threshold":0.25,',
        
        '"models":["ETS(A,N,N)","NAIVE"],',
        
        '"selection_method":"walk_forward_mae",',
        
        '"direction_method":"validated_direction_strategy",',
        
        '"range_method":"model_prediction_interval"}'
        
      ),
    
    active =
      TRUE,
    
    created_at =
      max(
        forecast$generated_at,
        na.rm = TRUE
      )
    
  ) %>%
  
  select(
    
    forecast_model_version_name,
    
    algorithm,
    
    target_definition,
    
    training_start_date,
    
    training_end_date,
    
    validation_mae,
    
    validation_rmse,
    
    validation_mape,
    
    validation_interval_level,
    
    configuration,
    
    active,
    
    created_at
    
  )

# =========================================================
# 12. CREATE PRICE FORECAST STAGING DATA
# =========================================================
#
# This corresponds to:
#
#   price_forecast
#
# The database developer will resolve:
#
#   seafood_item_id
#   location_id
#   forecast_model_version_id
#   source_snapshot_id
#
# from canonical/lookup fields.
# =========================================================

price_forecast_staging <- forecast %>%
  
  mutate(
    
    location_name =
      location,
    
    model_version_name =
      forecast_model_version_name,
    
    model_algorithm =
      forecast_algorithm,
    
    forecast_origin_date =
      reference_week +
      days(6),
    
    forecast_week_start =
      forecast_week,
    
    current_reference_price =
      reference_price,
    
    lower_bound =
      round(
        lower_bound,
        2
      ),
    
    upper_bound =
      round(
        upper_bound,
        2
      ),
    
    expected_price =
      round(
        expected_price,
        2
      )
    
  ) %>%
  
  select(
    
    forecast_id,
    
    canonical_name,
    
    location_name,
    
    model_version_name,
    
    model_algorithm,
    
    forecast_engine_version,
    
    forecast_origin_date,
    
    forecast_week_start,
    
    horizon_weeks,
    
    current_reference_price,
    
    expected_price,
    
    lower_bound,
    
    upper_bound,
    
    outlook,
    
    directional_outlook_label,
    
    quality_status,
    
    generated_at
    
  ) %>%
  
  arrange(
    
    canonical_name,
    
    forecast_week_start
    
  )

# =========================================================
# 13. CREATE BACKEND LOOKUP VIEW
# =========================================================
#
# This is specifically for your friend.
#
# It tells the backend developer which database IDs must
# be resolved before insertion.
# =========================================================

database_lookup_contract <- price_forecast_staging %>%
  
  distinct(
    
    canonical_name,
    
    location_name,
    
    model_version_name,
    
    model_algorithm
    
  ) %>%
  
  arrange(
    
    canonical_name
    
  ) %>%
  
  mutate(
    
    required_database_lookup =
      "seafood_item_id + location_id + forecast_model_version_id + source_snapshot_id",
    
    seafood_lookup_key =
      canonical_name,
    
    location_lookup_key =
      location_name,
    
    model_version_lookup_key =
      model_version_name
    
  )

# =========================================================
# 14. CREATE EXAMPLE DATABASE COLUMN MAP
# =========================================================

column_mapping <- tribble(
  
  ~staging_column,
  ~database_table,
  ~database_column,
  ~handling,
  
  "canonical_name",
  "seafood_item",
  "seafood_item_id",
  "Resolve by canonical seafood master; never use name as stored FK.",
  
  "location_name",
  "location",
  "location_id",
  "Resolve Selangor location UUID.",
  
  "model_version_name",
  "forecast_model_version",
  "forecast_model_version_id",
  "Resolve active model version UUID.",
  
  "forecast_id",
  "price_forecast",
  "price_forecast_id",
  "Use generated UUID or preserve deterministic UUID only if backend policy allows.",
  
  "forecast_origin_date",
  "price_forecast",
  "forecast_origin_date",
  "Completed reference week end date.",
  
  "forecast_week_start",
  "price_forecast",
  "forecast_week_start",
  "Monday forecast week start.",
  
  "horizon_weeks",
  "price_forecast",
  "horizon_weeks",
  "1 to 4.",
  
  "current_reference_price",
  "price_forecast",
  "current_reference_price",
  "Latest completed-week reference price.",
  
  "expected_price",
  "price_forecast",
  "expected_price",
  "Point estimate.",
  
  "lower_bound",
  "price_forecast",
  "lower_bound",
  "Lower forecast boundary.",
  
  "upper_bound",
  "price_forecast",
  "upper_bound",
  "Upper forecast boundary.",
  
  "outlook",
  "price_forecast",
  "outlook",
  "LIKELY_INCREASE / LIKELY_DECREASE / AR​​OUND_CURRENT_LEVELS.",
  
  "quality_status",
  "price_forecast",
  "quality_status",
  "VALID / SPARSE_DATA.",
  
  "generated_at",
  "price_forecast",
  "generated_at",
  "UTC timestamp.",
  
  "model_version_name",
  "forecast_model_version",
  "forecast_model_version_id",
  "Required FK.",
  
  "source_snapshot_id",
  "price_forecast",
  "source_snapshot_id",
  "Resolved to PriceCatcher source snapshot used for forecast."
  
)

# =========================================================
# 15. VALIDATE RANGE VALUES
# =========================================================

range_errors <-
  price_forecast_staging %>%
  
  filter(
    
    lower_bound >
      upper_bound |
      
      expected_price <
      lower_bound |
      
      expected_price >
      upper_bound |
      
      current_reference_price <=
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
    "Invalid production forecast values detected."
  )
  
}

# =========================================================
# 16. VALIDATE UNIQUE FORECAST KEYS
# =========================================================
#
# Database uniqueness:
#
#   seafood_item_id
#   location_id
#   forecast_model_version_id
#   forecast_week_start
#
# We cannot validate UUID FKs here, but we can validate the
# natural equivalent.
# =========================================================

duplicate_natural_keys <-
  price_forecast_staging %>%
  
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
    duplicate_natural_keys
  ) > 0
) {
  
  print(
    duplicate_natural_keys,
    n = Inf
  )
  
  stop(
    "Duplicate natural forecast keys detected."
  )
  
}

# =========================================================
# 17. SUMMARY FOR DATABASE DEVELOPER
# =========================================================

database_summary <- tibble(
  
  metric = c(
    
    "Forecast rows",
    
    "Forecastable fish",
    
    "Forecast weeks per fish",
    
    "Reference week",
    
    "First forecast week",
    
    "Last forecast week",
    
    "Location",
    
    "Forecast engine"
    
  ),
  
  value = c(
    
    as.character(
      nrow(
        price_forecast_staging
      )
    ),
    
    as.character(
      n_distinct(
        price_forecast_staging$canonical_name
      )
    ),
    
    "4",
    
    as.character(
      min(
        price_forecast_staging$forecast_origin_date
      ) -
        days(6)
    ),
    
    as.character(
      min(
        price_forecast_staging$forecast_week_start
      )
    ),
    
    as.character(
      max(
        price_forecast_staging$forecast_week_start
      )
    ),
    
    unique(
      price_forecast_staging$location_name
    ),
    
    unique(
      price_forecast_staging$model_algorithm
    )
    
  )
  
)

# =========================================================
# 18. PRINT
# =========================================================

cat("\n========================================\n")
cat("DATABASE FORECAST STAGING PACKAGE\n")
cat("========================================\n\n")

print(
  database_summary
)

cat("\n========================================\n")
cat("MODEL VERSION STAGING\n")
cat("========================================\n\n")

print(
  model_version_staging,
  n = Inf
)

cat("\n========================================\n")
cat("DATABASE LOOKUP CONTRACT\n")
cat("========================================\n\n")

print(
  database_lookup_contract,
  n = Inf
)

cat("\n========================================\n")
cat("PRICE FORECAST STAGING SAMPLE\n")
cat("========================================\n\n")

print(
  price_forecast_staging %>%
    head(20),
  n = 20
)

# =========================================================
# 19. SAVE MODEL VERSION STAGING
# =========================================================

model_version_file <- file.path(
  output_dir,
  "db_forecast_model_version_staging.csv"
)

write_csv(
  model_version_staging,
  model_version_file
)

# =========================================================
# 20. SAVE PRICE FORECAST STAGING
# =========================================================

forecast_staging_file <- file.path(
  output_dir,
  "db_price_forecast_staging.csv"
)

write_csv(
  price_forecast_staging,
  forecast_staging_file
)

# =========================================================
# 21. SAVE LOOKUP CONTRACT
# =========================================================

lookup_contract_file <- file.path(
  output_dir,
  "db_forecast_lookup_contract.csv"
)

write_csv(
  database_lookup_contract,
  lookup_contract_file
)

# =========================================================
# 22. SAVE COLUMN MAPPING
# =========================================================

column_mapping_file <- file.path(
  output_dir,
  "db_forecast_column_mapping.csv"
)

write_csv(
  column_mapping,
  column_mapping_file
)

# =========================================================
# 23. SAVE SUMMARY
# =========================================================

database_summary_file <- file.path(
  output_dir,
  "db_forecast_staging_summary.csv"
)

write_csv(
  database_summary,
  database_summary_file
)

# =========================================================
# 24. FINAL STATUS
# =========================================================

cat("\n========================================\n")
cat("STEP 33A COMPLETE\n")
cat("========================================\n\n")

message(
  "Model version staging: ",
  model_version_file
)

message(
  "Price forecast staging: ",
  forecast_staging_file
)

message(
  "Lookup contract: ",
  lookup_contract_file
)

message(
  "Column mapping: ",
  column_mapping_file
)

message(
  "Summary: ",
  database_summary_file
)

message(
  "\nDatabase forecast rows: ",
  nrow(
    price_forecast_staging
  )
)

message(
  "Forecastable fish: ",
  n_distinct(
    price_forecast_staging$canonical_name
  )
)

message(
  "All staging validations passed."
)

