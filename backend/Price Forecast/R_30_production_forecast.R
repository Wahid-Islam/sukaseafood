# =========================================================
# SukaSeafood Price Forecasting
# Step 30 — Production Four-Week Forecast Generator
# =========================================================
#
# Purpose:
#   Generate the production-ready four-week price outlook
#   for all eligible WWF × PriceCatcher fish in Selangor.
#
# For DENSE + ETS fish:
#   Fit final ETS(A,N,N) using all usable dense history.
#   Use ETS 80% prediction interval.
#
# For DENSE + NAIVE fish:
#   Point forecast = latest completed weekly price.
#   Forecast range = empirically calibrated using historical
#   out-of-sample naive errors.
#
# For SPARSE + ETS fish:
#   Fit final ETS(A,N,N) using all sparse weekly history.
#   Use ETS 80% prediction interval.
#
# For SPARSE + NAIVE fish:
#   Point forecast = latest completed sparse weekly price.
#   Forecast range = empirically calibrated using historical
#   out-of-sample naive errors.
#
# Unavailable fish:
#   No production forecast is generated.
#
# IMPORTANT:
#   The week beginning 24 Aug 2026 is incomplete because the
#   latest PriceCatcher source currently ends on 27 Aug 2026.
#
# Therefore:
#   Reference week = 17 Aug 2026
#
# =========================================================

library(tidyverse)
library(forecast)
library(lubridate)

processed_dir <- "data/processed"
lookup_dir <- "data/lookup"
output_dir <- "outputs"

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# =========================================================
# 1. LOAD FINAL ELIGIBILITY TABLE
# =========================================================

eligibility <- read_csv(
  file.path(
    output_dir,
    "final_forecast_eligibility.csv"
  ),
  show_col_types = FALSE
)

# =========================================================
# 2. LOAD CLEAN WEEKLY DATA
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
# 3. LOAD BACKTEST RESULTS
#
# These are used to calibrate naive-model uncertainty.
# =========================================================

dense_backtest <- read_csv(
  file.path(
    output_dir,
    "multi_fish_ets_backtest_summary.csv"
  ),
  show_col_types = FALSE
)

sparse_backtest <- read_csv(
  file.path(
    output_dir,
    "sparse_fish_backtest_predictions.csv"
  ),
  show_col_types = FALSE
)

dense_backtest_predictions <- read_csv(
  file.path(
    output_dir,
    "multi_fish_ets_backtest_summary.csv"
  ),
  show_col_types = FALSE
)

# =========================================================
# 4. LOAD DENSE WALK-FORWARD PREDICTIONS
#
# We need the actual historical errors for each dense fish
# when calculating empirical naive uncertainty.
# =========================================================

dense_prediction_file <- file.path(
  output_dir,
  "multi_fish_ets_backtest_predictions.csv"
)

# ---------------------------------------------------------
# If this file exists, use it.
# Otherwise use the available walk-forward prediction file.
# ---------------------------------------------------------

if (
  file.exists(
    dense_prediction_file
  )
) {
  
  dense_predictions <- read_csv(
    dense_prediction_file,
    show_col_types = FALSE
  )
  
} else {
  
  warning(
    paste(
      "Dense prediction file not found:",
      dense_prediction_file
    )
  )
  
  dense_predictions <- tibble()
  
}

# =========================================================
# 5. DETERMINE REFERENCE DATE
# =========================================================

reference_week <-
  max(
    eligibility$completed_week[
      eligibility$quality_status %in%
        c(
          "VALID",
          "SPARSE_DATA"
        )
    ],
    na.rm = TRUE
  )

message(
  "Production reference week: ",
  reference_week
)

# =========================================================
# 6. DETERMINE FORECAST HORIZON
# =========================================================

forecast_weeks <-
  seq(
    from =
      reference_week +
      weeks(1),
    
    by =
      "1 week",
    
    length.out =
      4
  )

# =========================================================
# 7. IDENTIFY FORECASTABLE FISH
# =========================================================

forecastable <- eligibility %>%
  filter(
    quality_status %in%
      c(
        "VALID",
        "SPARSE_DATA"
      )
  ) %>%
  arrange(
    canonical_name
  )

cat("\n========================================\n")
cat("PRODUCTION FORECAST UNIVERSE\n")
cat("========================================\n\n")

message(
  "Forecastable fish: ",
  nrow(
    forecastable
  )
)

print(
  
  forecastable %>%
    select(
      canonical_name,
      data_density,
      model_to_use,
      quality_status,
      completed_week,
      reference_price
    ),
  
  n = Inf
  
)

# =========================================================
# 8. FUNCTION — NAIVE EMPIRICAL ERROR MARGIN
# =========================================================
#
# For naive models:
#
#   predicted price = previous week's actual price
#
# We estimate the forecast range using historical absolute
# one-week-ahead naive errors.
#
# The 80th percentile gives an empirical 80% symmetric
# range around the naive point forecast.
# =========================================================

get_naive_margin <- function(
    fish,
    density
) {
  
  if (
    density ==
    "DENSE"
  ) {
    
    if (
      nrow(
        dense_predictions
      ) == 0
    ) {
      
      return(
        NA_real_
      )
      
    }
    
    fish_errors <- dense_predictions %>%
      
      filter(
        canonical_name ==
          fish
      )
    
    # -----------------------------------------------------
    # Attempt to identify the naive error column.
    # -----------------------------------------------------
    
    if (
      "naive_absolute_error" %in%
      names(
        fish_errors
      )
    ) {
      
      absolute_errors <-
        fish_errors$naive_absolute_error
      
    } else if (
      "naive_error" %in%
      names(
        fish_errors
      )
    ) {
      
      absolute_errors <-
        abs(
          fish_errors$naive_error
        )
      
    } else {
      
      return(
        NA_real_
      )
      
    }
    
  } else {
    
    # -----------------------------------------------------
    # Sparse fish
    # -----------------------------------------------------
    
    fish_errors <- sparse_backtest %>%
      filter(
        canonical_name ==
          fish
      )
    
    if (
      "naive_absolute_error" %in%
      names(
        fish_errors
      )
    ) {
      
      absolute_errors <-
        fish_errors$naive_absolute_error
      
    } else if (
      "naive_error" %in%
      names(
        fish_errors
      )
    ) {
      
      absolute_errors <-
        abs(
          fish_errors$naive_error
        )
      
    } else {
      
      return(
        NA_real_
      )
      
    }
    
  }
  
  absolute_errors <-
    absolute_errors[
      !is.na(
        absolute_errors
      )
    ]
  
  if (
    length(
      absolute_errors
    ) < 8
  ) {
    
    return(
      NA_real_
    )
    
  }
  
  quantile(
    absolute_errors,
    probs = 0.80,
    na.rm = TRUE,
    names = FALSE
  )
  
}

# =========================================================
# 9. FUNCTION — FINAL ETS FORECAST
# =========================================================

generate_ets_forecast <- function(
    fish,
    density,
    reference_week
) {
  
  if (
    density ==
    "DENSE"
  ) {
    
    fish_data <- weekly_dense %>%
      filter(
        canonical_name ==
          fish,
        week_start <=
          reference_week
      ) %>%
      arrange(
        week_start
      )
    
  } else {
    
    fish_data <- weekly_sparse %>%
      filter(
        canonical_name ==
          fish,
        week_start <=
          reference_week
      ) %>%
      arrange(
        week_start
      )
    
  }
  
  if (
    nrow(
      fish_data
    ) < 8
  ) {
    
    return(
      NULL
    )
    
  }
  
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
    is.null(
      final_ets
    )
  ) {
    
    return(
      NULL
    )
    
  }
  
  forecast_result <- forecast(
    final_ets,
    h = 4,
    level = 80
  )
  
  tibble(
    
    forecast_week =
      forecast_weeks,
    
    expected_price =
      as.numeric(
        forecast_result$mean
      ),
    
    lower_80 =
      as.numeric(
        forecast_result$lower[, 1]
      ),
    
    upper_80 =
      as.numeric(
        forecast_result$upper[, 1]
      )
    
  )
  
}

# =========================================================
# 10. GENERATE FORECASTS
# =========================================================

forecast_results <- list()

model_artifacts <- list()

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
  
  model <-
    forecastable$model_to_use[i]
  
  quality <-
    forecastable$quality_status[i]
  
  reference_price <-
    forecastable$reference_price[i]
  
  fish_reference_week <-
    forecastable$completed_week[i]
  
  cat(
    "\n----------------------------------------\n"
  )
  
  cat(
    "Forecasting: ",
    fish,
    "\n",
    sep = ""
  )
  
  cat(
    "----------------------------------------\n"
  )
  
  message(
    "Density: ",
    density
  )
  
  message(
    "Model: ",
    model
  )
  
  message(
    "Quality: ",
    quality
  )
  
  message(
    "Reference week: ",
    fish_reference_week
  )
  
  message(
    "Reference price: RM",
    round(
      reference_price,
      2
    )
  )
  
  # =======================================================
  # ETS MODEL
  # =======================================================
  
  if (
    model ==
    "ETS(A,N,N)"
  ) {
    
    ets_forecast <-
      generate_ets_forecast(
        fish =
          fish,
        
        density =
          density,
        
        reference_week =
          fish_reference_week
      )
    
    if (
      is.null(
        ets_forecast
      )
    ) {
      
      warning(
        paste(
          "ETS forecast failed for:",
          fish
        )
      )
      
      next
      
    }
    
    fish_forecast <- ets_forecast %>%
      mutate(
        
        canonical_name =
          fish,
        
        location =
          "Selangor",
        
        reference_week =
          fish_reference_week,
        
        reference_price =
          reference_price,
        
        model_used =
          "ETS(A,N,N)",
        
        quality_status =
          quality,
        
        expected_change =
          expected_price -
          reference_price,
        
        expected_change_pct =
          (
            expected_price /
              reference_price -
              1
          ) * 100,
        
        range_width =
          upper_80 -
          lower_80
        
      )
    
    # -----------------------------------------------------
    # Direction
    #
    # We distinguish "likely movement" from "around current
    # levels" using the interval rather than merely comparing
    # two point estimates.
    # -----------------------------------------------------
    
    fish_forecast <- fish_forecast %>%
      mutate(
        
        outlook =
          case_when(
            
            lower_80 >
              reference_price
            ~ "LIKELY_INCREASE",
            
            upper_80 <
              reference_price
            ~ "LIKELY_DECREASE",
            
            TRUE
            ~ "AROUND_CURRENT_LEVELS"
            
          )
        
      )
    
    model_artifacts[[
      fish
    ]] <- NULL
    
  }
  
  # =======================================================
  # NAIVE MODEL
  # =======================================================
  
  else if (
    model ==
    "NAIVE"
  ) {
    
    naive_margin <-
      get_naive_margin(
        fish =
          fish,
        
        density =
          density
      )
    
    if (
      is.na(
        naive_margin
      )
    ) {
      
      warning(
        paste(
          "Naive empirical margin could not be calculated for:",
          fish
        )
      )
      
      next
      
    }
    
    fish_forecast <- tibble(
      
      canonical_name =
        fish,
      
      location =
        "Selangor",
      
      reference_week =
        fish_reference_week,
      
      reference_price =
        reference_price,
      
      forecast_week =
        forecast_weeks,
      
      expected_price =
        reference_price,
      
      lower_80 =
        reference_price -
        naive_margin,
      
      upper_80 =
        reference_price +
        naive_margin,
      
      model_used =
        "NAIVE",
      
      quality_status =
        quality,
      
      expected_change =
        0,
      
      expected_change_pct =
        0,
      
      range_width =
        naive_margin * 2
      
    )
    
    fish_forecast <- fish_forecast %>%
      mutate(
        
        outlook =
          "AROUND_CURRENT_LEVELS"
        
      )
    
  }
  
  else {
    
    warning(
      paste(
        "Unknown model for:",
        fish
      )
    )
    
    next
    
  }
  
  # =======================================================
  # COMMON USER-FACING FIELDS
  # =======================================================
  
  fish_forecast <- fish_forecast %>%
    mutate(
      
      outlook_label =
        case_when(
          
          outlook ==
            "LIKELY_INCREASE"
          ~ "Likely to increase",
          
          outlook ==
            "LIKELY_DECREASE"
          ~ "Likely to decrease",
          
          TRUE
          ~ "Around current levels"
          
        ),
      
      lower_bound =
        pmax(
          lower_80,
          0
        ),
      
      upper_bound =
        pmax(
          upper_80,
          0
        )
      
    ) %>%
    select(
      
      canonical_name,
      
      location,
      
      reference_week,
      
      reference_price,
      
      forecast_week,
      
      expected_price,
      
      lower_bound,
      
      upper_bound,
      
      outlook,
      
      outlook_label,
      
      expected_change,
      
      expected_change_pct,
      
      range_width,
      
      model_used,
      
      quality_status
      
    )
  
  forecast_results[[
    length(
      forecast_results
    ) + 1
  ]] <-
    fish_forecast
}

# =========================================================
# 11. COMBINE FINAL FORECASTS
# =========================================================

final_forecast <-
  bind_rows(
    forecast_results
  ) %>%
  arrange(
    canonical_name,
    forecast_week
  )

# =========================================================
# 12. ADD FORECAST IDS
# =========================================================
#
# This creates a stable application-facing identifier.
# =========================================================

final_forecast <- final_forecast %>%
  mutate(
    
    forecast_id =
      paste(
        gsub(
          "[^A-Za-z0-9]+",
          "_",
          canonical_name
        ),
        
        format(
          forecast_week,
          "%Y%m%d"
        ),
        
        sep = "_"
        
      ),
    
    generated_at =
      Sys.time(),
    
    model_version =
      "2026-08-v1"
    
  ) %>%
  select(
    
    forecast_id,
    
    everything()
    
  )

# =========================================================
# 13. VALIDATION — FORECAST WEEK COUNT
# =========================================================

forecast_counts <- final_forecast %>%
  count(
    canonical_name
  )

invalid_counts <- forecast_counts %>%
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
    "One or more forecastable fish do not have exactly four forecast weeks."
  )
  
}

# =========================================================
# 14. VALIDATION — REQUIRED FIELDS
# =========================================================

required_columns <- c(
  
  "forecast_id",
  "canonical_name",
  "location",
  "reference_week",
  "reference_price",
  "forecast_week",
  "expected_price",
  "lower_bound",
  "upper_bound",
  "outlook",
  "model_used",
  "quality_status"
  
)

missing_columns <-
  setdiff(
    required_columns,
    names(
      final_forecast
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
# 15. VALIDATION — RANGE ORDER
# =========================================================

bad_ranges <- final_forecast %>%
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
# 16. VALIDATION — REFERENCE PRICE
# =========================================================

missing_reference <- final_forecast %>%
  filter(
    is.na(
      reference_price
    )
  )

if (
  nrow(
    missing_reference
  ) > 0
) {
  
  print(
    missing_reference,
    n = Inf
  )
  
  stop(
    "Forecasts are missing reference prices."
  )
  
}

# =========================================================
# 17. PRINT FINAL FORECAST
# =========================================================

cat("\n========================================\n")
cat("FINAL FOUR-WEEK PRODUCTION FORECAST\n")
cat("========================================\n\n")

print(
  
  final_forecast %>%
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
      
      outlook_label
      
    ),
  
  n = Inf
  
)

# =========================================================
# 18. FORECAST SUMMARY BY FISH
# =========================================================

cat("\n========================================\n")
cat("FORECAST SUMMARY BY FISH\n")
cat("========================================\n\n")

summary_by_fish <- final_forecast %>%
  group_by(
    canonical_name
  ) %>%
  summarise(
    
    quality_status =
      first(
        quality_status
      ),
    
    model_used =
      first(
        model_used
      ),
    
    reference_week =
      first(
        reference_week
      ),
    
    reference_price =
      first(
        reference_price
      ),
    
    forecast_start =
      min(
        forecast_week
      ),
    
    forecast_end =
      max(
        forecast_week
      ),
    
    minimum_expected_price =
      min(
        expected_price
      ),
    
    maximum_expected_price =
      max(
        expected_price
      ),
    
    minimum_lower_bound =
      min(
        lower_bound
      ),
    
    maximum_upper_bound =
      max(
        upper_bound
      ),
    
    .groups = "drop"
    
  ) %>%
  arrange(
    canonical_name
  )

print(
  summary_by_fish,
  n = Inf
)

# =========================================================
# 19. OUTLOOK DISTRIBUTION
# =========================================================

cat("\n========================================\n")
cat("OUTLOOK DISTRIBUTION\n")
cat("========================================\n\n")

print(
  
  final_forecast %>%
    count(
      outlook
    ) %>%
    arrange(
      desc(n)
    )
  
)

# =========================================================
# 20. QUALITY DISTRIBUTION
# =========================================================

cat("\n========================================\n")
cat("QUALITY DISTRIBUTION\n")
cat("========================================\n\n")

print(
  
  final_forecast %>%
    distinct(
      canonical_name,
      quality_status
    ) %>%
    count(
      quality_status
    ) %>%
    arrange(
      desc(n)
    )
  
)

# =========================================================
# 21. SAVE PRODUCTION FORECAST
# =========================================================

forecast_file <- file.path(
  output_dir,
  "production_four_week_forecast.csv"
)

write_csv(
  final_forecast,
  forecast_file
)

# =========================================================
# 22. SAVE FISH SUMMARY
# =========================================================

summary_file <- file.path(
  output_dir,
  "production_forecast_summary.csv"
)

write_csv(
  summary_by_fish,
  summary_file
)

# =========================================================
# 23. SAVE FORECASTABLE FISH LIST
# =========================================================

forecastable_file <- file.path(
  output_dir,
  "production_forecastable_fish.csv"
)

write_csv(
  forecastable %>%
    select(
      
      canonical_name,
      
      model_to_use,
      
      quality_status,
      
      data_density,
      
      completed_week,
      
      reference_price,
      
      reference_active_days,
      
      reference_observation_count
      
    ),
  forecastable_file
)

# =========================================================
# 24. FINAL MESSAGES
# =========================================================

cat("\n========================================\n")
cat("STEP 30 COMPLETE\n")
cat("========================================\n\n")

message(
  "Production forecast saved to: ",
  forecast_file
)

message(
  "Forecast summary saved to: ",
  summary_file
)

message(
  "Forecastable fish list saved to: ",
  forecastable_file
)

message(
  "Forecastable fish: ",
  n_distinct(
    final_forecast$canonical_name
  )
)

message(
  "Forecast rows generated: ",
  nrow(
    final_forecast
  )
)

message(
  "Reference week: ",
  reference_week
)

message(
  "Forecast horizon: ",
  min(
    final_forecast$forecast_week
  ),
  " → ",
  max(
    final_forecast$forecast_week
  )
)
