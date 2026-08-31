# =========================================================
# SukaSeafood Price Forecasting
# Step 28B — Sparse-Fish Backtesting
# =========================================================
#
# Purpose:
#   Evaluate whether the five currently-updated but sparsely
#   observed fish can support a one-week-ahead price outlook.
#
# Sparse fish:
#   - Bawal Hitam
#   - Ikan Merah
#   - Jenahak
#   - Siakap Putih
#   - Tenggiri
#
# Unlike Step 28:
#   We DO NOT require active_days >= 5.
#
# Instead:
#   - use weeks containing at least 1 observed day
#   - keep the actual weekly observation pattern
#   - evaluate Naive vs ETS out-of-sample
#
# IMPORTANT:
#   The week beginning 24 Aug 2026 is incomplete in the
#   current source (data ends 27 Aug), so it is excluded
#   from modelling.
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
# 1. LOAD CLEAN DAILY DATA
# =========================================================

daily <- read_csv(
  file.path(
    processed_dir,
    "multi_fish_selangor_daily_clean.csv"
  ),
  show_col_types = FALSE
) %>%
  mutate(
    date = as.Date(date)
  ) %>%
  arrange(
    canonical_name,
    date
  )

# =========================================================
# 2. BUILD WEEKLY SERIES FROM ALL OBSERVED DAYS
#
# IMPORTANT:
#   No five-day active-week restriction here.
# =========================================================

weekly_sparse <- daily %>%
  mutate(
    
    week_start =
      floor_date(
        date,
        unit = "week",
        week_start = 1
      )
    
  ) %>%
  group_by(
    canonical_name,
    week_start
  ) %>%
  summarise(
    
    weekly_median =
      median(
        median_price,
        na.rm = TRUE
      ),
    
    weekly_p25 =
      quantile(
        median_price,
        0.25,
        na.rm = TRUE
      ),
    
    weekly_p75 =
      quantile(
        median_price,
        0.75,
        na.rm = TRUE
      ),
    
    weekly_mean =
      mean(
        median_price,
        na.rm = TRUE
      ),
    
    observation_count =
      sum(
        observation_count
      ),
    
    premise_count =
      sum(
        premise_count
      ),
    
    active_days =
      n_distinct(
        date
      ),
    
    .groups = "drop"
    
  )

# =========================================================
# 3. REMOVE INCOMPLETE CURRENT WEEK
#
# Latest raw source date is 27 Aug 2026.
# Therefore week beginning 24 Aug is incomplete.
# =========================================================

latest_source_date <-
  max(
    daily$date,
    na.rm = TRUE
  )

current_week_start <-
  floor_date(
    latest_source_date,
    unit = "week",
    week_start = 1
  )

weekly_sparse <- weekly_sparse %>%
  filter(
    week_start <
      current_week_start
  )

# =========================================================
# 4. FILTER TO THE FIVE SPARSE FISH
# =========================================================

sparse_fish <- c(
  "Bawal Hitam",
  "Ikan Merah",
  "Jenahak",
  "Siakap Putih",
  "Tenggiri"
)

weekly_sparse <- weekly_sparse %>%
  filter(
    canonical_name %in%
      sparse_fish
  ) %>%
  arrange(
    canonical_name,
    week_start
  )

cat("\n========================================\n")
cat("SPARSE-FISH DATASET\n")
cat("========================================\n\n")

message(
  "Latest raw source date: ",
  latest_source_date
)

message(
  "Incomplete current week excluded: ",
  current_week_start
)

message(
  "Sparse fish included: ",
  n_distinct(
    weekly_sparse$canonical_name
  )
)

print(
  weekly_sparse %>%
    group_by(
      canonical_name
    ) %>%
    summarise(
      total_weeks =
        n(),
      first_week =
        min(week_start),
      last_week =
        max(week_start),
      .groups = "drop"
    ),
  n = Inf
)

# =========================================================
# 5. MODEL SETTINGS
# =========================================================

initial_training_size <- 12

minimum_test_predictions <- 8

prediction_results <- list()
summary_results <- list()

# =========================================================
# 6. LOOP THROUGH SPARSE FISH
# =========================================================

for (
  fish in sparse_fish
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
  
  fish_data <- weekly_sparse %>%
    filter(
      canonical_name ==
        fish
    ) %>%
    arrange(
      week_start
    )
  
  total_weeks <-
    nrow(
      fish_data
    )
  
  message(
    "Available weekly observations: ",
    total_weeks
  )
  
  # -------------------------------------------------------
  # Check total history
  # -------------------------------------------------------
  
  if (
    total_weeks <=
    initial_training_size
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
      
      naive_mae =
        NA_real_,
      
      ets_mae =
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
        tail(
          fish_data$weekly_median,
          1
        ),
      
      evaluation_status =
        "INSUFFICIENT_HISTORY"
      
    )
    
    next
    
  }
  
  # -------------------------------------------------------
  # Walk-forward evaluation
  # -------------------------------------------------------
  
  fish_results <- list()
  
  first_test_index <-
    initial_training_size + 1
  
  for (
    test_index in
    first_test_index:total_weeks
  ) {
    
    # -----------------------------------------------------
    # Training observations
    # -----------------------------------------------------
    
    train_prices <-
      fish_data$weekly_median[
        1:(test_index - 1)
      ]
    
    # -----------------------------------------------------
    # Current completed week
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
    # Actual next observed week
    # -----------------------------------------------------
    
    actual_price <-
      fish_data$weekly_median[
        test_index
      ]
    
    forecast_week <-
      fish_data$week_start[
        test_index
      ]
    
    # -----------------------------------------------------
    # Fit ETS
    # -----------------------------------------------------
    
    ets_model <- tryCatch(
      
      ets(
        ts(
          train_prices,
          frequency = 1
        )
      ),
      
      error = function(e)
        NULL
      
    )
    
    if (
      is.null(
        ets_model
      )
    ) {
      
      next
      
    }
    
    # -----------------------------------------------------
    # Forecast one week ahead
    # -----------------------------------------------------
    
    forecast_result <- forecast(
      ets_model,
      h = 1,
      level = 80
    )
    
    ets_prediction <-
      as.numeric(
        forecast_result$mean[1]
      )
    
    ets_lower_80 <-
      as.numeric(
        forecast_result$lower[1, 1]
      )
    
    ets_upper_80 <-
      as.numeric(
        forecast_result$upper[1, 1]
      )
    
    # -----------------------------------------------------
    # Store
    # -----------------------------------------------------
    
    fish_results[[
      length(
        fish_results
      ) + 1
    ]] <- tibble(
      
      canonical_name =
        fish,
      
      week_start =
        forecast_week,
      
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
        ets_lower_80,
      
      ets_upper_80 =
        ets_upper_80
      
    )
    
  }
  
  # -------------------------------------------------------
  # Combine
  # -------------------------------------------------------
  
  fish_results <-
    bind_rows(
      fish_results
    )
  
  test_count <-
    nrow(
      fish_results
    )
  
  # -------------------------------------------------------
  # Check test size
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
      
      naive_mae =
        NA_real_,
      
      ets_mae =
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
        tail(
          fish_data$weekly_median,
          1
        ),
      
      evaluation_status =
        "INSUFFICIENT_TEST_HISTORY"
      
    )
    
    next
    
  }
  
  # =======================================================
  # CALCULATE ERRORS
  # =======================================================
  
  fish_results <- fish_results %>%
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
  # METRICS
  # =======================================================
  
  naive_mae <-
    mean(
      fish_results$naive_absolute_error
    )
  
  ets_mae <-
    mean(
      fish_results$ets_absolute_error
    )
  
  naive_rmse <-
    sqrt(
      mean(
        fish_results$naive_squared_error
      )
    )
  
  ets_rmse <-
    sqrt(
      mean(
        fish_results$ets_squared_error
      )
    )
  
  naive_mape <-
    mean(
      fish_results$naive_percentage_error
    ) * 100
  
  ets_mape <-
    mean(
      fish_results$ets_percentage_error
    ) * 100
  
  interval_coverage <-
    mean(
      fish_results$interval_contains_actual
    ) * 100
  
  interval_width <-
    mean(
      fish_results$interval_width
    )
  
  mae_improvement_pct <-
    (
      naive_mae -
        ets_mae
    ) /
    naive_mae *
    100
  
  # -------------------------------------------------------
  # Determine winner
  # -------------------------------------------------------
  
  evaluation_status <-
    ifelse(
      ets_mae <
        naive_mae,
      "ETS_BETTER",
      "NAIVE_BETTER"
    )
  
  # =======================================================
  # STORE
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
    
    naive_mae =
      naive_mae,
    
    ets_mae =
      ets_mae,
    
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
      tail(
        fish_data$weekly_median,
        1
      ),
    
    evaluation_status =
      evaluation_status
    
  )
  
  prediction_results[[
    length(prediction_results) + 1
  ]] <-
    fish_results
}

# =========================================================
# 7. COMBINE RESULTS
# =========================================================

summary_table <-
  bind_rows(
    summary_results
  ) %>%
  arrange(
    canonical_name
  )

predictions <-
  bind_rows(
    prediction_results
  ) %>%
  arrange(
    canonical_name,
    week_start
  )

# =========================================================
# 8. PRINT SUMMARY
# =========================================================

cat("\n========================================\n")
cat("SPARSE-FISH BACKTEST RESULTS\n")
cat("========================================\n\n")

print(
  summary_table,
  n = Inf
)

# =========================================================
# 9. INTERVAL QUALITY
# =========================================================

cat("\n========================================\n")
cat("SPARSE-FISH INTERVAL QUALITY\n")
cat("========================================\n\n")

print(
  
  summary_table %>%
    filter(
      !is.na(
        ets_interval_coverage
      )
    ) %>%
    select(
      
      canonical_name,
      
      total_weeks,
      
      test_predictions,
      
      ets_mae,
      
      ets_interval_coverage,
      
      ets_interval_width
      
    ) %>%
    arrange(
      canonical_name
    ),
  
  n = Inf
  
)

# =========================================================
# 10. COVERAGE BY TEST WEEK
#
# This helps us see whether the model only works in a
# particular part of the short history.
# =========================================================

if (
  nrow(predictions) > 0
) {
  
  cat("\n========================================\n")
  cat("SPARSE-FISH RECENT TEST PREDICTIONS\n")
  cat("========================================\n\n")
  
  print(
    
    predictions %>%
      group_by(
        canonical_name
      ) %>%
      slice_tail(
        n = 10
      ) %>%
      ungroup(),
    
    n = Inf
    
  )
  
}

# =========================================================
# 11. PRODUCTION DIAGNOSTIC
#
# We are more conservative here.
#
# A sparse fish is only a possible candidate when:
#
#   - >= 8 test observations
#   - model has a lower MAE
#   - interval coverage >= 70%
#
# Otherwise it is limited/unavailable.
# =========================================================

summary_table <- summary_table %>%
  mutate(
    
    sparse_support =
      case_when(
        
        evaluation_status ==
          "ETS_BETTER" &
          ets_interval_coverage >= 70
        ~ "ETS_LIMITED_CANDIDATE",
        
        evaluation_status ==
          "NAIVE_BETTER" &
          test_predictions >= 8
        ~ "NAIVE_LIMITED_CANDIDATE",
        
        test_predictions >= 8
        ~ "WEAK_EVIDENCE",
        
        TRUE
        ~ "INSUFFICIENT"
        
      )
    
  )

cat("\n========================================\n")
cat("SPARSE-FISH SUPPORT STATUS\n")
cat("========================================\n\n")

print(
  
  summary_table %>%
    select(
      
      canonical_name,
      
      total_weeks,
      
      test_predictions,
      
      evaluation_status,
      
      sparse_support,
      
      naive_mae,
      
      ets_mae,
      
      mae_improvement_pct,
      
      ets_interval_coverage,
      
      ets_interval_width,
      
      latest_week,
      
      latest_price
      
    ),
  
  n = Inf
  
)

# =========================================================
# 12. SAVE
# =========================================================

write_csv(
  
  summary_table,
  
  file.path(
    output_dir,
    "sparse_fish_backtest_summary.csv"
  )
  
)

write_csv(
  
  predictions,
  
  file.path(
    output_dir,
    "sparse_fish_backtest_predictions.csv"
  )
  
)

write_csv(
  
  weekly_sparse,
  
  file.path(
    processed_dir,
    "sparse_fish_weekly_series.csv"
  )
  
)

message(
  "\nSaved sparse-fish summary to: ",
  file.path(
    output_dir,
    "sparse_fish_backtest_summary.csv"
  )
)

message(
  "Saved sparse-fish predictions to: ",
  file.path(
    output_dir,
    "sparse_fish_backtest_predictions.csv"
  )
)

message(
  "Saved sparse-fish weekly series to: ",
  file.path(
    processed_dir,
    "sparse_fish_weekly_series.csv"
  )
)
