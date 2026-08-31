# =========================================================
# SukaSeafood Price Forecasting
# Step 32 — Integrate Production Forecast + Direction
# =========================================================
#
# Purpose:
#   Combine the production price forecast from Step 30 with
#   the validated directional strategy from Step 31.
#
# Final output:
#
#   1. Four-week price forecast
#      - expected price
#      - lower bound
#      - upper bound
#
#   2. Current directional outlook
#      - LIKELY_INCREASE
#      - LIKELY_DECREASE
#      - NO_STRONG_SIGNAL
#
#   3. Model / data quality metadata
#
# IMPORTANT:
#   Directional validation is based on historical out-of-
#   sample performance.
#
#   The CURRENT directional signal is calculated using only
#   information available up to the latest completed week.
#
#   We DO NOT reuse the last historical backtest signal.
#
# =========================================================

library(tidyverse)
library(forecast)
library(lubridate)

processed_dir <- "data/processed"
output_dir <- "outputs"

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# =========================================================
# 1. LOAD PRODUCTION FORECAST
# =========================================================

production_forecast <- read_csv(
  file.path(
    output_dir,
    "production_four_week_forecast.csv"
  ),
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
      )
    
  ) %>%
  arrange(
    canonical_name,
    forecast_week
  )

# =========================================================
# 2. LOAD DIRECTIONAL STRATEGY SELECTION
# =========================================================

direction_selection <- read_csv(
  file.path(
    output_dir,
    "final_direction_outlook.csv"
  ),
  show_col_types = FALSE
)

# =========================================================
# 3. LOAD FINAL ELIGIBILITY TABLE
# =========================================================

eligibility <- read_csv(
  file.path(
    output_dir,
    "final_forecast_eligibility.csv"
  ),
  show_col_types = FALSE
)

# =========================================================
# 4. LOAD DENSE WEEKLY SERIES
# =========================================================

weekly_dense <- read_csv(
  file.path(
    processed_dir,
    "multi_fish_selangor_weekly_clean.csv"
  ),
  show_col_types = FALSE
) %>%
  mutate(
    
    week_start =
      as.Date(
        week_start
      )
    
  ) %>%
  arrange(
    canonical_name,
    week_start
  )

# =========================================================
# 5. LOAD SPARSE WEEKLY SERIES
# =========================================================

weekly_sparse <- read_csv(
  file.path(
    processed_dir,
    "sparse_fish_weekly_series.csv"
  ),
  show_col_types = FALSE
) %>%
  mutate(
    
    week_start =
      as.Date(
        week_start
      )
    
  ) %>%
  arrange(
    canonical_name,
    week_start
  )

# =========================================================
# 6. SETTINGS
# =========================================================

movement_threshold <- 0.25

# =========================================================
# 7. IDENTIFY LATEST COMPLETED WEEK
# =========================================================

reference_week <-
  max(
    production_forecast$reference_week,
    na.rm = TRUE
  )

message(
  "Production reference week: ",
  reference_week
)

# =========================================================
# 8. FORECASTABLE FISH
# =========================================================

forecastable <- eligibility %>%
  filter(
    quality_status %in%
      c(
        "VALID",
        "SPARSE_DATA"
      )
  ) %>%
  select(
    
    canonical_name,
    
    data_density,
    
    model_to_use,
    
    quality_status,
    
    completed_week,
    
    reference_price,
    
    selected_test_predictions,
    
    selected_ets_interval_coverage,
    
    selected_ets_interval_width
    
  ) %>%
  arrange(
    canonical_name
  )

cat("\n========================================\n")
cat("FORECASTABLE FISH\n")
cat("========================================\n\n")

print(
  forecastable,
  n = Inf
)

# =========================================================
# 9. HELPER — SIGNAL CLASSIFICATION
# =========================================================

classify_signal <- function(
    change,
    threshold
) {
  
  if (
    is.na(
      change
    )
  ) {
    
    return(
      "NO_SIGNAL"
    )
    
  }
  
  if (
    change >
    threshold
  ) {
    
    return(
      "UP"
    )
    
  }
  
  if (
    change <
    -threshold
  ) {
    
    return(
      "DOWN"
    )
    
  }
  
  return(
    "NO_SIGNAL"
  )
  
}

# =========================================================
# 10. HELPER — GET CURRENT FISH SERIES
# =========================================================

get_fish_series <- function(
    fish,
    density
) {
  
  if (
    density ==
    "DENSE"
  ) {
    
    return(
      
      weekly_dense %>%
        filter(
          canonical_name ==
            fish,
          
          week_start <=
            reference_week
        ) %>%
        arrange(
          week_start
        )
      
    )
    
  }
  
  return(
    
    weekly_sparse %>%
      filter(
        canonical_name ==
          fish,
        
        week_start <=
          reference_week
      ) %>%
      arrange(
        week_start
      )
    
  )
  
}

# =========================================================
# 11. CALCULATE CURRENT DIRECTIONAL SIGNAL
# =========================================================
#
# The selected strategy was validated historically in Step 31.
#
# We now calculate that strategy using CURRENT information.
#
# ---------------------------------------------------------
# model_signal
# ---------------------------------------------------------
#
# Fit the selected model using all currently available
# completed-week data and compare its one-week forecast to
# the current completed-week price.
#
# ---------------------------------------------------------
# last_week_signal
# ---------------------------------------------------------
#
# Current latest weekly movement.
#
# ---------------------------------------------------------
# four_week_signal
# ---------------------------------------------------------
#
# Price change over the most recent four weeks.
#
# ---------------------------------------------------------
# four_week_median_signal
# ---------------------------------------------------------
#
# Current price relative to the recent four-week median.
#
# =========================================================

current_direction_results <- list()

for (
  i in seq_len(
    nrow(
      forecastable
    )
  )
) {
  
  fish <-
    forecastable$canonical_name[i]
  
  density <-
    forecastable$data_density[i]
  
  selected_model <-
    forecastable$model_to_use[i]
  
  # -------------------------------------------------------
  # Retrieve selected strategy
  # -------------------------------------------------------
  
  strategy_row <-
    direction_selection %>%
    filter(
      canonical_name ==
        fish
    )
  
  if (
    nrow(
      strategy_row
    ) == 0
  ) {
    
    selected_strategy <-
      "NO_STRONG_SIGNAL"
    
    validation_accuracy <-
      NA_real_
    
    validation_call_rate <-
      0
    
  } else {
    
    selected_strategy <-
      strategy_row$selected_strategy[1]
    
    validation_accuracy <-
      strategy_row$directional_accuracy[1]
    
    validation_call_rate <-
      strategy_row$direction_call_rate[1]
    
  }
  
  # -------------------------------------------------------
  # Get series
  # -------------------------------------------------------
  
  fish_data <-
    get_fish_series(
      fish,
      density
    )
  
  fish_data <-
    fish_data %>%
    arrange(
      week_start
    )
  
  if (
    nrow(
      fish_data
    ) < 5
  ) {
    
    current_direction_results[[
      length(
        current_direction_results
      ) + 1
    ]] <- tibble(
      
      canonical_name =
        fish,
      
      selected_strategy =
        selected_strategy,
      
      validation_accuracy =
        validation_accuracy,
      
      validation_call_rate =
        validation_call_rate,
      
      current_price =
        NA_real_,
      
      current_week =
        as.Date(
          NA
        ),
      
      strategy_signal =
        "NO_SIGNAL",
      
      strategy_change =
        NA_real_
      
    )
    
    next
    
  }
  
  # -------------------------------------------------------
  # Current reference
  # -------------------------------------------------------
  
  current_price <-
    tail(
      fish_data$weekly_median,
      1
    )
  
  current_week <-
    tail(
      fish_data$week_start,
      1
    )
  
  # -------------------------------------------------------
  # Default
  # -------------------------------------------------------
  
  strategy_signal <-
    "NO_SIGNAL"
  
  strategy_change <-
    NA_real_
  
  # =======================================================
  # MODEL SIGNAL
  # =======================================================
  
  if (
    selected_strategy ==
    "model_signal"
  ) {
    
    if (
      selected_model ==
      "ETS(A,N,N)"
    ) {
      
      price_series <-
        fish_data$weekly_median
      
      final_ets <- tryCatch(
        
        ets(
          ts(
            price_series,
            frequency = 1
          )
        ),
        
        error = function(e)
          NULL
        
      )
      
      if (
        !is.null(
          final_ets
        )
      ) {
        
        current_forecast <-
          forecast(
            final_ets,
            h = 1,
            level = 80
          )
        
        predicted_price <-
          as.numeric(
            current_forecast$mean[1]
          )
        
        strategy_change <-
          predicted_price -
          current_price
        
        strategy_signal <-
          classify_signal(
            strategy_change,
            movement_threshold
          )
        
      }
      
    }
    
    # -----------------------------------------------------
    # Naive models have no model-based direction.
    # -----------------------------------------------------
    
    else {
      
      strategy_signal <-
        "NO_SIGNAL"
      
      strategy_change <-
        0
      
    }
    
  }
  
  # =======================================================
  # LAST-WEEK MOMENTUM
  # =======================================================
  
  else if (
    selected_strategy ==
    "last_week_signal"
  ) {
    
    if (
      nrow(
        fish_data
      ) >= 2
    ) {
      
      strategy_change <-
        fish_data$weekly_median[
          nrow(
            fish_data
          )
        ] -
        fish_data$weekly_median[
          nrow(
            fish_data
          ) - 1
        ]
      
      strategy_signal <-
        classify_signal(
          strategy_change,
          movement_threshold
        )
      
    }
    
  }
  
  # =======================================================
  # FOUR-WEEK MOMENTUM
  # =======================================================
  
  else if (
    selected_strategy ==
    "four_week_signal"
  ) {
    
    if (
      nrow(
        fish_data
      ) >= 5
    ) {
      
      strategy_change <-
        fish_data$weekly_median[
          nrow(
            fish_data
          )
        ] -
        fish_data$weekly_median[
          nrow(
            fish_data
          ) - 4
        ]
      
      strategy_signal <-
        classify_signal(
          strategy_change,
          movement_threshold
        )
      
    }
    
  }
  
  # =======================================================
  # FOUR-WEEK MEDIAN
  # =======================================================
  
  else if (
    selected_strategy ==
    "four_week_median_signal"
  ) {
    
    if (
      nrow(
        fish_data
      ) >= 4
    ) {
      
      recent_median <-
        median(
          
          tail(
            fish_data$weekly_median,
            4
          ),
          
          na.rm = TRUE
          
        )
      
      strategy_change <-
        current_price -
        recent_median
      
      strategy_signal <-
        classify_signal(
          strategy_change,
          movement_threshold
        )
      
    }
    
  }
  
  # =======================================================
  # NO STRONG SIGNAL
  # =======================================================
  
  else {
    
    strategy_signal <-
      "NO_SIGNAL"
    
    strategy_change <-
      NA_real_
    
  }
  
  # -------------------------------------------------------
  # Store current directional result
  # -------------------------------------------------------
  
  current_direction_results[[
    length(
      current_direction_results
    ) + 1
  ]] <- tibble(
    
    canonical_name =
      fish,
    
    selected_strategy =
      selected_strategy,
    
    validation_accuracy =
      validation_accuracy,
    
    validation_call_rate =
      validation_call_rate,
    
    current_price =
      current_price,
    
    current_week =
      current_week,
    
    strategy_signal =
      strategy_signal,
    
    strategy_change =
      strategy_change
    
  )
  
}

current_direction <-
  bind_rows(
    current_direction_results
  ) %>%
  arrange(
    canonical_name
  )

# =========================================================
# 12. USER-FACING OUTLOOK
# =========================================================

current_direction <- current_direction %>%
  mutate(
    
    directional_outlook =
      case_when(
        
        strategy_signal ==
          "UP"
        ~ "LIKELY_INCREASE",
        
        strategy_signal ==
          "DOWN"
        ~ "LIKELY_DECREASE",
        
        TRUE
        ~ "NO_STRONG_SIGNAL"
        
      ),
    
    directional_outlook_label =
      case_when(
        
        directional_outlook ==
          "LIKELY_INCREASE"
        ~ "Likely to increase",
        
        directional_outlook ==
          "LIKELY_DECREASE"
        ~ "Likely to decrease",
        
        TRUE
        ~ "No strong directional signal"
        
      )
    
  )

# =========================================================
# 13. PRINT CURRENT DIRECTION
# =========================================================

cat("\n========================================\n")
cat("CURRENT DIRECTIONAL OUTLOOK\n")
cat("========================================\n\n")

print(
  
  current_direction %>%
    select(
      
      canonical_name,
      
      selected_strategy,
      
      validation_accuracy,
      
      validation_call_rate,
      
      current_week,
      
      current_price,
      
      strategy_change,
      
      strategy_signal,
      
      directional_outlook,
      
      directional_outlook_label
      
    ),
  
  n = Inf
  
)

# =========================================================
# 14. MERGE WITH PRODUCTION FORECAST
# =========================================================
#
# Direction is a CURRENT fish-level signal.
#
# It is repeated across the four forecast rows so the API has
# one self-contained record for each forecast week.
#
# The field name explicitly identifies this as the current
# directional outlook, rather than a separate forecast for
# each future week.
# =========================================================

integrated_forecast <-
  production_forecast %>%
  
  left_join(
    
    current_direction %>%
      select(
        
        canonical_name,
        
        selected_strategy,
        
        validation_accuracy,
        
        validation_call_rate,
        
        directional_outlook,
        
        directional_outlook_label,
        
        strategy_change
        
      ),
    
    by =
      "canonical_name"
    
  ) %>%
  
  left_join(
    
    forecastable %>%
      select(
        
        canonical_name,
        
        data_density,
        
        selected_test_predictions,
        
        selected_ets_interval_coverage,
        
        selected_ets_interval_width
        
      ),
    
    by =
      "canonical_name"
    
  ) %>%
  
  mutate(
    
    direction_threshold =
      movement_threshold,
    
    direction_evidence =
      case_when(
        
        selected_strategy ==
          "NO_STRONG_SIGNAL"
        ~ "No validated directional strategy met the minimum evidence threshold.",
        
        !is.na(
          validation_accuracy
        )
        ~ paste0(
          
          "Validated directional strategy accuracy: ",
          
          round(
            validation_accuracy,
            1
          ),
          
          "%."
          
        ),
        
        TRUE
        ~ "No strong directional evidence."
        
      )
    
  )

# =========================================================
# 15. ORDER FINAL COLUMNS
# =========================================================

integrated_forecast <-
  integrated_forecast %>%
  select(
    
    forecast_id,
    
    canonical_name,
    
    location,
    
    quality_status,
    
    data_density,
    
    model_used,
    
    reference_week,
    
    reference_price,
    
    forecast_week,
    
    expected_price,
    
    lower_bound,
    
    upper_bound,
    
    range_width,
    
    expected_change,
    
    expected_change_pct,
    
    outlook,
    
    outlook_label,
    
    directional_outlook,
    
    directional_outlook_label,
    
    selected_strategy,
    
    validation_accuracy,
    
    validation_call_rate,
    
    strategy_change,
    
    direction_threshold,
    
    direction_evidence,
    
    generated_at,
    
    model_version
    
  ) %>%
  arrange(
    
    canonical_name,
    
    forecast_week
    
  )

# =========================================================
# 16. VALIDATION — 4 WEEKS PER FISH
# =========================================================

forecast_counts <-
  integrated_forecast %>%
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
    "One or more forecastable fish do not have four forecast weeks."
  )
  
}

# =========================================================
# 17. VALIDATION — DIRECTION VALUES
# =========================================================

valid_direction_values <- c(
  
  "LIKELY_INCREASE",
  
  "LIKELY_DECREASE",
  
  "NO_STRONG_SIGNAL"
  
)

invalid_direction <-
  integrated_forecast %>%
  filter(
    
    !directional_outlook %in%
      valid_direction_values
    
  )

if (
  nrow(
    invalid_direction
  ) > 0
) {
  
  print(
    invalid_direction,
    n = Inf
  )
  
  stop(
    "Invalid directional outlook values detected."
  )
  
}

# =========================================================
# 18. VALIDATION — RANGE ORDER
# =========================================================

bad_ranges <-
  integrated_forecast %>%
  filter(
    
    lower_bound >
      upper_bound |
      
      expected_price <
      lower_bound |
      
      expected_price >
      upper_bound
    
  )

if (
  nrow(
    bad_ranges
  ) > 0
) {
  
  print(
    bad_ranges,
    n = Inf
  )
  
  stop(
    "Invalid forecast ranges detected."
  )
  
}

# =========================================================
# 19. VALIDATION — FORECASTABLE FISH COUNT
# =========================================================

integrated_fish_count <-
  n_distinct(
    integrated_forecast$canonical_name
  )

expected_fish_count <-
  nrow(
    forecastable
  )

if (
  integrated_fish_count !=
  expected_fish_count
) {
  
  stop(
    paste(
      "Forecast fish count mismatch. Expected",
      expected_fish_count,
      "but found",
      integrated_fish_count
    )
  )
  
}

# =========================================================
# 20. PRINT FINAL API-SHAPED OUTPUT
# =========================================================

cat("\n========================================\n")
cat("INTEGRATED PRODUCTION FORECAST\n")
cat("========================================\n\n")

print(
  
  integrated_forecast %>%
    select(
      
      canonical_name,
      
      quality_status,
      
      model_used,
      
      reference_week,
      
      reference_price,
      
      forecast_week,
      
      expected_price,
      
      lower_bound,
      
      upper_bound,
      
      outlook_label,
      
      directional_outlook_label
      
    ),
  
  n = Inf
  
)

# =========================================================
# 21. DIRECTION DISTRIBUTION
# =========================================================

cat("\n========================================\n")
cat("FINAL DIRECTION DISTRIBUTION\n")
cat("========================================\n\n")

print(
  
  current_direction %>%
    count(
      directional_outlook
    ) %>%
    arrange(
      desc(n)
    )
  
)

# =========================================================
# 22. QUALITY × DIRECTION
# =========================================================

cat("\n========================================\n")
cat("QUALITY × DIRECTION\n")
cat("========================================\n\n")

print(
  
  integrated_forecast %>%
    distinct(
      
      canonical_name,
      
      quality_status,
      
      directional_outlook
      
    ) %>%
    arrange(
      quality_status,
      canonical_name
    ),
  
  n = Inf
  
)

# =========================================================
# 23. SAVE INTEGRATED FORECAST
# =========================================================

integrated_file <- file.path(
  output_dir,
  "production_forecast_with_direction.csv"
)

write_csv(
  
  integrated_forecast,
  
  integrated_file
  
)

# =========================================================
# 24. SAVE CURRENT FISH-LEVEL DIRECTION
# =========================================================

direction_file <- file.path(
  output_dir,
  "production_current_direction.csv"
)

write_csv(
  
  current_direction,
  
  direction_file
  
)

# =========================================================
# 25. SAVE API-FRIENDLY VIEW
# =========================================================
#
# This is a deliberately small table containing the fields
# most likely to be needed directly by the frontend.
# =========================================================

api_forecast <- integrated_forecast %>%
  select(
    
    forecast_id,
    
    canonical_name,
    
    location,
    
    forecast_week,
    
    reference_week,
    
    reference_price,
    
    expected_price,
    
    lower_bound,
    
    upper_bound,
    
    outlook_label,
    
    directional_outlook_label,
    
    model_used,
    
    quality_status,
    
    generated_at,
    
    model_version
    
  )

api_file <- file.path(
  output_dir,
  "production_forecast_api.csv"
)

write_csv(
  
  api_forecast,
  
  api_file
  
)

# =========================================================
# 26. FINAL MESSAGES
# =========================================================

cat("\n========================================\n")
cat("STEP 32 COMPLETE\n")
cat("========================================\n\n")

message(
  "Integrated forecast saved to: ",
  integrated_file
)

message(
  "Current direction table saved to: ",
  direction_file
)

message(
  "API-ready forecast saved to: ",
  api_file
)

message(
  "Forecastable fish: ",
  integrated_fish_count
)

message(
  "Forecast rows: ",
  nrow(
    integrated_forecast
  )
)

message(
  "Reference week: ",
  reference_week
)

message(
  "Forecast horizon: ",
  min(
    integrated_forecast$forecast_week
  ),
  " → ",
  max(
    integrated_forecast$forecast_week
  )
)

message(
  "Directionally positive fish: ",
  sum(
    current_direction$directional_outlook ==
      "LIKELY_INCREASE"
  )
)

message(
  "Directionally negative fish: ",
  sum(
    current_direction$directional_outlook ==
      "LIKELY_DECREASE"
  )
)

message(
  "No strong directional signal: ",
  sum(
    current_direction$directional_outlook ==
      "NO_STRONG_SIGNAL"
  )
)