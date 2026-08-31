# =========================================================
# SukaSeafood Price Forecasting
# Step 28 — Multi-Fish ETS Backtesting
# =========================================================
#
# Purpose:
#   Evaluate ETS separately for every supported fish in
#   the cleaned Selangor weekly PriceCatcher dataset.
#
# Compared against:
#   Naive baseline = next week's price equals current week's
#   completed weekly median.
#
# Outputs:
#   - Point forecast accuracy
#   - 80% prediction interval coverage
#   - Prediction interval width
#   - ETS vs Naive comparison
#   - Forecastability status
#
# IMPORTANT:
#   This is an evaluation script.
#   It does NOT create the final production forecasts.
# =========================================================

library(tidyverse)
library(forecast)

processed_dir <- "data/processed"
output_dir <- "outputs"

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# =========================================================
# 1. LOAD CLEAN WEEKLY DATA
# =========================================================

weekly <- read_csv(
  file.path(
    processed_dir,
    "multi_fish_selangor_weekly_clean.csv"
  ),
  show_col_types = FALSE
) %>%
  arrange(
    canonical_name,
    week_start
  )

# ---------------------------------------------------------
# Validate required columns
# ---------------------------------------------------------

required_columns <- c(
  "canonical_name",
  "week_start",
  "weekly_median",
  "active_days"
)

missing_columns <- setdiff(
  required_columns,
  names(weekly)
)

if (
  length(missing_columns) > 0
) {
  
  stop(
    paste(
      "Missing required columns:",
      paste(
        missing_columns,
        collapse = ", "
      )
    )
  )
  
}

# =========================================================
# 2. KEEP USABLE WEEKS
# =========================================================
#
# We only use weeks with at least five active days.
#
# This matches the cleaning/aggregation logic used for
# the Kembung model.
# =========================================================

weekly <- weekly %>%
  filter(
    active_days >= 5,
    week_start >= as.Date("2025-01-06")
  )

# =========================================================
# 3. IDENTIFY FISH
# =========================================================

fish_names <- weekly %>%
  distinct(
    canonical_name
  ) %>%
  arrange(
    canonical_name
  ) %>%
  pull(
    canonical_name
  )

cat("\n========================================\n")
cat("MULTI-FISH ETS BACKTEST\n")
cat("========================================\n\n")

message(
  "Fish with usable weekly data: ",
  length(
    fish_names
  )
)

print(
  fish_names
)

# =========================================================
# 4. MODEL SETTINGS
# =========================================================
#
# Long-history fish:
#   82-ish usable weeks
#
# Short-history fish:
#   ~20-26 usable weeks
#
# We therefore evaluate each fish using the same
# minimum-history principle, but report the number of
# genuine out-of-sample predictions separately.
# =========================================================

initial_training_size <- 12

minimum_total_weeks <- 20

minimum_test_predictions <- 8

# ---------------------------------------------------------
# Lists to store results
# ---------------------------------------------------------

prediction_results <- list()
summary_results <- list()

# =========================================================
# 5. LOOP THROUGH EVERY FISH
# =========================================================

for (
  fish in fish_names
) {
  
  cat(
    "\n----------------------------------------\n"
  )
  
  cat(
    "Processing: ",
    fish,
    "\n",
    sep = ""
  )
  
  cat(
    "----------------------------------------\n"
  )
  
  # -------------------------------------------------------
  # Fish-specific weekly series
  # -------------------------------------------------------
  
  fish_data <- weekly %>%
    filter(
      canonical_name ==
        fish
    ) %>%
    arrange(
      week_start
    )
  
  total_weeks <- nrow(
    fish_data
  )
  
  message(
    "Usable weeks: ",
    total_weeks
  )
  
  # =======================================================
  # 5A. CHECK TOTAL HISTORY
  # =======================================================
  
  if (
    total_weeks <
    minimum_total_weeks
  ) {
    
    summary_results[[
      length(summary_results) + 1
    ]] <- tibble(
      
      canonical_name =
        fish,
      
      total_weeks =
        total_weeks,
      
      test_predictions =
        0,
      
      evaluation_status =
        "INSUFFICIENT_HISTORY",
      
      naive_mae =
        NA_real_,
      
      ets_mae =
        NA_real_,
      
      mae_difference =
        NA_real_,
      
      mae_improvement_pct =
        NA_real_,
      
      naive_rmse =
        NA_real_,
      
      ets_rmse =
        NA_real_,
      
      naive_mape =
        NA_real_,
      
      ets_mape =
        NA_real_,
      
      ets_interval_coverage =
        NA_real_,
      
      ets_interval_width =
        NA_real_,
      
      latest_week =
        max(
          fish_data$week_start
        ),
      
      latest_price =
        fish_data$weekly_median[
          nrow(fish_data)
        ]
      
    )
    
    next
  }
  
  # =======================================================
  # 5B. WALK-FORWARD ETS
  # =======================================================
  
  fish_predictions <- list()
  
  first_test_index <-
    initial_training_size + 1
  
  if (
    first_test_index >
    total_weeks
  ) {
    
    summary_results[[
      length(summary_results) + 1
    ]] <- tibble(
      
      canonical_name =
        fish,
      
      total_weeks =
        total_weeks,
      
      test_predictions =
        0,
      
      evaluation_status =
        "INSUFFICIENT_TEST_HISTORY",
      
      naive_mae =
        NA_real_,
      
      ets_mae =
        NA_real_,
      
      mae_difference =
        NA_real_,
      
      mae_improvement_pct =
        NA_real_,
      
      naive_rmse =
        NA_real_,
      
      ets_rmse =
        NA_real_,
      
      naive_mape =
        NA_real_,
      
      ets_mape =
        NA_real_,
      
      ets_interval_coverage =
        NA_real_,
      
      ets_interval_width =
        NA_real_,
      
      latest_week =
        max(
          fish_data$week_start
        ),
      
      latest_price =
        fish_data$weekly_median[
          nrow(fish_data)
        ]
      
    )
    
    next
  }
  
  # -------------------------------------------------------
  # Walk forward one week at a time
  # -------------------------------------------------------
  
  for (
    test_index in
    first_test_index:total_weeks
  ) {
    
    # -----------------------------------------------------
    # Training history
    # -----------------------------------------------------
    
    train_prices <-
      fish_data$weekly_median[
        1:(test_index - 1)
      ]
    
    # -----------------------------------------------------
    # Current observed week
    # -----------------------------------------------------
    
    current_price <-
      fish_data$weekly_median[
        test_index - 1
      ]
    
    current_week <-
      fish_data$week_start[
        test_index - 1
      ]
    
    # -----------------------------------------------------
    # Actual next week
    # -----------------------------------------------------
    
    actual_price <-
      fish_data$weekly_median[
        test_index
      ]
    
    test_week <-
      fish_data$week_start[
        test_index
      ]
    
    # -----------------------------------------------------
    # Fit ETS
    #
    # frequency = 1
    #
    # Deliberately non-seasonal because the available
    # history does not justify a 52-week seasonal ETS.
    # -----------------------------------------------------
    
    ets_model <- tryCatch(
      
      ets(
        ts(
          train_prices,
          frequency = 1
        )
      ),
      
      error = function(e) {
        
        NULL
        
      }
      
    )
    
    # -----------------------------------------------------
    # If model fails, skip this iteration
    # -----------------------------------------------------
    
    if (
      is.null(
        ets_model
      )
    ) {
      
      next
      
    }
    
    # -----------------------------------------------------
    # One-step forecast
    # -----------------------------------------------------
    
    fc <- forecast(
      ets_model,
      h = 1,
      level = 80
    )
    
    ets_prediction <-
      as.numeric(
        fc$mean[1]
      )
    
    ets_lower <-
      as.numeric(
        fc$lower[1, 1]
      )
    
    ets_upper <-
      as.numeric(
        fc$upper[1, 1]
      )
    
    # -----------------------------------------------------
    # Store prediction
    # -----------------------------------------------------
    
    fish_predictions[[
      length(
        fish_predictions
      ) + 1
    ]] <- tibble(
      
      canonical_name =
        fish,
      
      week_start =
        test_week,
      
      previous_week_start =
        current_week,
      
      current_price =
        current_price,
      
      actual_price =
        actual_price,
      
      naive_prediction =
        current_price,
      
      ets_prediction =
        ets_prediction,
      
      ets_lower_80 =
        ets_lower,
      
      ets_upper_80 =
        ets_upper
      
    )
  }
  
  # =======================================================
  # 5C. COMBINE PREDICTIONS
  # =======================================================
  
  fish_predictions <-
    bind_rows(
      fish_predictions
    )
  
  test_count <-
    nrow(
      fish_predictions
    )
  
  # -------------------------------------------------------
  # Require enough genuine test observations
  # -------------------------------------------------------
  
  if (
    test_count <
    minimum_test_predictions
  ) {
    
    summary_results[[
      length(summary_results) + 1
    ]] <- tibble(
      
      canonical_name =
        fish,
      
      total_weeks =
        total_weeks,
      
      test_predictions =
        test_count,
      
      evaluation_status =
        "INSUFFICIENT_TEST_HISTORY",
      
      naive_mae =
        NA_real_,
      
      ets_mae =
        NA_real_,
      
      mae_difference =
        NA_real_,
      
      mae_improvement_pct =
        NA_real_,
      
      naive_rmse =
        NA_real_,
      
      ets_rmse =
        NA_real_,
      
      naive_mape =
        NA_real_,
      
      ets_mape =
        NA_real_,
      
      ets_interval_coverage =
        NA_real_,
      
      ets_interval_width =
        NA_real_,
      
      latest_week =
        max(
          fish_data$week_start
        ),
      
      latest_price =
        fish_data$weekly_median[
          nrow(fish_data)
        ]
      
    )
    
    next
  }
  
  # =======================================================
  # 5D. CALCULATE ERRORS
  # =======================================================
  
  fish_predictions <- fish_predictions %>%
    mutate(
      
      naive_error =
        actual_price -
        naive_prediction,
      
      ets_error =
        actual_price -
        ets_prediction,
      
      naive_absolute_error =
        abs(
          naive_error
        ),
      
      ets_absolute_error =
        abs(
          ets_error
        ),
      
      naive_squared_error =
        naive_error^2,
      
      ets_squared_error =
        ets_error^2,
      
      naive_percentage_error =
        abs(
          naive_error /
            actual_price
        ),
      
      ets_percentage_error =
        abs(
          ets_error /
            actual_price
        ),
      
      interval_contains_actual =
        actual_price >=
        ets_lower_80 &
        actual_price <=
        ets_upper_80,
      
      interval_width =
        ets_upper_80 -
        ets_lower_80
      
    )
  
  # =======================================================
  # 5E. POINT FORECAST METRICS
  # =======================================================
  
  naive_mae <-
    mean(
      fish_predictions$naive_absolute_error
    )
  
  ets_mae <-
    mean(
      fish_predictions$ets_absolute_error
    )
  
  naive_rmse <-
    sqrt(
      mean(
        fish_predictions$naive_squared_error
      )
    )
  
  ets_rmse <-
    sqrt(
      mean(
        fish_predictions$ets_squared_error
      )
    )
  
  naive_mape <-
    mean(
      fish_predictions$naive_percentage_error
    ) * 100
  
  ets_mape <-
    mean(
      fish_predictions$ets_percentage_error
    ) * 100
  
  # =======================================================
  # 5F. INTERVAL METRICS
  # =======================================================
  
  interval_coverage <-
    mean(
      fish_predictions$interval_contains_actual
    ) * 100
  
  interval_width <-
    mean(
      fish_predictions$interval_width
    )
  
  # =======================================================
  # 5G. ETS IMPROVEMENT VS NAIVE
  # =======================================================
  
  mae_difference <-
    ets_mae -
    naive_mae
  
  mae_improvement_pct <-
    (
      naive_mae -
        ets_mae
    ) /
    naive_mae *
    100
  
  # -------------------------------------------------------
  # ETS is considered better only if MAE is lower.
  # -------------------------------------------------------
  
  if (
    ets_mae <
    naive_mae
  ) {
    
    evaluation_status <-
      "ETS_BETTER"
    
  } else {
    
    evaluation_status <-
      "NAIVE_BETTER"
    
  }
  
  # =======================================================
  # 5H. STORE SUMMARY
  # =======================================================
  
  summary_results[[
    length(summary_results) + 1
  ]] <- tibble(
    
    canonical_name =
      fish,
    
    total_weeks =
      total_weeks,
    
    test_predictions =
      test_count,
    
    evaluation_status =
      evaluation_status,
    
    naive_mae =
      naive_mae,
    
    ets_mae =
      ets_mae,
    
    mae_difference =
      mae_difference,
    
    mae_improvement_pct =
      mae_improvement_pct,
    
    naive_rmse =
      naive_rmse,
    
    ets_rmse =
      ets_rmse,
    
    naive_mape =
      naive_mape,
    
    ets_mape =
      ets_mape,
    
    ets_interval_coverage =
      interval_coverage,
    
    ets_interval_width =
      interval_width,
    
    latest_week =
      max(
        fish_data$week_start
      ),
    
    latest_price =
      fish_data$weekly_median[
        nrow(fish_data)
      ]
    
  )
  
  # =======================================================
  # 5I. STORE PREDICTIONS
  # =======================================================
  
  prediction_results[[
    length(prediction_results) + 1
  ]] <- fish_predictions
}

# =========================================================
# 6. COMBINE ALL RESULTS
# =========================================================

model_summary <-
  bind_rows(
    summary_results
  ) %>%
  arrange(
    canonical_name
  )

backtest_predictions <-
  bind_rows(
    prediction_results
  ) %>%
  arrange(
    canonical_name,
    week_start
  )

# =========================================================
# 7. PRINT MODEL SUMMARY
# =========================================================

cat("\n========================================\n")
cat("MULTI-FISH ETS BACKTEST RESULTS\n")
cat("========================================\n\n")

print(
  model_summary,
  n = Inf
)

# =========================================================
# 8. MODEL STATUS COUNTS
# =========================================================

cat("\n========================================\n")
cat("MODEL STATUS COUNTS\n")
cat("========================================\n\n")

print(
  model_summary %>%
    count(
      evaluation_status
    ) %>%
    arrange(
      desc(n)
    )
)

# =========================================================
# 9. STRONG ETS CANDIDATES
# =========================================================

cat("\n========================================\n")
cat("ETS BETTER THAN NAIVE\n")
cat("========================================\n\n")

print(
  
  model_summary %>%
    filter(
      evaluation_status ==
        "ETS_BETTER"
    ) %>%
    arrange(
      ets_mae
    ),
  
  n = Inf
  
)

# =========================================================
# 10. NAIVE-BETTER FISH
# =========================================================

cat("\n========================================\n")
cat("NAIVE BETTER THAN ETS\n")
cat("========================================\n\n")

print(
  
  model_summary %>%
    filter(
      evaluation_status ==
        "NAIVE_BETTER"
    ) %>%
    arrange(
      naive_mae
    ),
  
  n = Inf
  
)

# =========================================================
# 11. INTERVAL QUALITY
# =========================================================

cat("\n========================================\n")
cat("ETS INTERVAL QUALITY\n")
cat("========================================\n\n")

print(
  
  model_summary %>%
    filter(
      !is.na(
        ets_interval_coverage
      )
    ) %>%
    select(
      
      canonical_name,
      
      test_predictions,
      
      ets_interval_coverage,
      
      ets_interval_width,
      
      ets_mae
      
    ) %>%
    arrange(
      canonical_name
    ),
  
  n = Inf
  
)

# =========================================================
# 12. IDENTIFY POTENTIAL PRODUCTION CANDIDATES
#
# This is only a diagnostic flag.
#
# Strong:
#   ≥40 test predictions AND ETS better than naive
#
# Limited:
#   8–39 test predictions AND ETS better than naive
#
# Naive preferred:
#   naive better
#
# Insufficient:
#   not enough history/test observations
# =========================================================

model_summary <- model_summary %>%
  mutate(
    
    production_candidate =
      case_when(
        
        evaluation_status ==
          "ETS_BETTER" &
          test_predictions >= 40
        ~ "STRONG_SUPPORT",
        
        evaluation_status ==
          "ETS_BETTER" &
          test_predictions >= 8
        ~ "LIMITED_SUPPORT",
        
        evaluation_status ==
          "NAIVE_BETTER"
        ~ "NAIVE_PREFERRED",
        
        TRUE
        ~ "NOT_SUPPORTED"
        
      )
    
  )

cat("\n========================================\n")
cat("PRODUCTION SUPPORT STATUS\n")
cat("========================================\n\n")

print(
  
  model_summary %>%
    select(
      
      canonical_name,
      
      total_weeks,
      
      test_predictions,
      
      evaluation_status,
      
      production_candidate,
      
      naive_mae,
      
      ets_mae,
      
      mae_improvement_pct,
      
      ets_interval_coverage,
      
      ets_interval_width
      
    ) %>%
    arrange(
      production_candidate,
      canonical_name
    ),
  
  n = Inf
  
)

# =========================================================
# 13. SAVE MODEL SUMMARY
# =========================================================

write_csv(
  model_summary,
  file.path(
    output_dir,
    "multi_fish_ets_backtest_summary.csv"
  )
)

# =========================================================
# 14. SAVE ALL OUT-OF-SAMPLE PREDICTIONS
# =========================================================

write_csv(
  backtest_predictions,
  file.path(
    output_dir,
    "multi_fish_ets_backtest_predictions.csv"
  )
)

# =========================================================
# 15. FINAL MESSAGE
# =========================================================

message(
  "\nSaved multi-fish model summary to: ",
  file.path(
    output_dir,
    "multi_fish_ets_backtest_summary.csv"
  )
)

message(
  "Saved multi-fish backtest predictions to: ",
  file.path(
    output_dir,
    "multi_fish_ets_backtest_predictions.csv"
  )
)
