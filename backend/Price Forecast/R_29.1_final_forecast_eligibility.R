# =========================================================
# SukaSeafood Price Forecasting
# Step 29.1 — Final Forecast Eligibility & Model Selection
# =========================================================
#
# Purpose:
#   Create the definitive production decision table for all
#   supported WWF × PriceCatcher fish.
#
# Combines:
#   - Dense-fish ETS backtesting
#   - Sparse-fish ETS backtesting
#   - Current data freshness
#   - Data density
#   - Latest completed weekly price
#
# Outputs:
#   - Model to use
#   - Forecast quality status
#   - Data density
#   - Data freshness
#   - Current reference price
#   - Reason for decision
#
# IMPORTANT:
#   This script does NOT generate forecasts.
#   Step 30 generates the actual four-week forecasts.
#
# =========================================================


library(tidyverse)
library(lubridate)


# =========================================================
# 1. DIRECTORIES
# =========================================================

processed_dir <- "data/processed"
lookup_dir <- "data/lookup"
output_dir <- "outputs"

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)


# =========================================================
# 2. LOAD DENSE-FISH BACKTEST
# =========================================================

dense_results <- read_csv(
  file.path(
    output_dir,
    "multi_fish_ets_backtest_summary.csv"
  ),
  show_col_types = FALSE
)


# =========================================================
# 3. LOAD SPARSE-FISH BACKTEST
# =========================================================

sparse_results <- read_csv(
  file.path(
    output_dir,
    "sparse_fish_backtest_summary.csv"
  ),
  show_col_types = FALSE
)


# =========================================================
# 4. LOAD CLEAN DAILY DATA
# =========================================================

daily <- read_csv(
  file.path(
    processed_dir,
    "multi_fish_selangor_daily_clean.csv"
  ),
  show_col_types = FALSE
) %>%
  mutate(
    date = as.Date(
      date
    )
  ) %>%
  arrange(
    canonical_name,
    date
  )


# =========================================================
# 5. LOAD DENSE WEEKLY DATA
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
# 6. LOAD SPARSE WEEKLY DATA
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
# 7. LOAD MASTER FISH MAPPING
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
      "Mapping file not found:",
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
    "Mapping file must contain a 'canonical_name' column."
  )
  
}


master_fish <- fish_mapping %>%
  distinct(
    canonical_name
  ) %>%
  arrange(
    canonical_name
  )


# =========================================================
# 8. MASTER FISH VALIDATION
# =========================================================

cat("\n========================================\n")
cat("MASTER FISH LIST\n")
cat("========================================\n\n")


message(
  "Fish in master mapping: ",
  nrow(
    master_fish
  )
)


print(
  master_fish,
  n = Inf
)


# =========================================================
# 9. LATEST ACTUAL SOURCE DATE
# =========================================================

latest_source_date <-
  max(
    daily$date,
    na.rm = TRUE
  )


message(
  "\nLatest actual PriceCatcher observation: ",
  latest_source_date
)


# =========================================================
# 10. LAST COMPLETED MODELLING WEEK
# =========================================================
#
# Example:
#
#   source ends Thursday 27 Aug 2026
#
#   week 24 Aug → 30 Aug is incomplete
#
#   latest completed week = 17 Aug 2026
#
# =========================================================

current_week_start <-
  floor_date(
    latest_source_date,
    unit = "week",
    week_start = 1
  )


last_completed_week <-
  current_week_start -
  weeks(1)


message(
  "Latest completed modelling week: ",
  last_completed_week
)


# =========================================================
# 11. RAW FISH PROFILE
# =========================================================

fish_raw_profile <- daily %>%
  
  group_by(
    canonical_name
  ) %>%
  
  summarise(
    
    latest_observation_date =
      max(
        date,
        na.rm = TRUE
      ),
    
    total_daily_observations =
      n(),
    
    .groups = "drop"
    
  )


# =========================================================
# 12. DENSE WEEKLY PROFILE
# =========================================================

dense_profile <- weekly_dense %>%
  
  group_by(
    canonical_name
  ) %>%
  
  summarise(
    
    total_usable_weeks_dense =
      n(),
    
    weeks_5plus_days_dense =
      sum(
        active_days >= 5
      ),
    
    latest_dense_week =
      max(
        week_start,
        na.rm = TRUE
      ),
    
    latest_dense_price =
      weekly_median[
        which.max(
          week_start
        )
      ],
    
    latest_dense_active_days =
      active_days[
        which.max(
          week_start
        )
      ],
    
    .groups = "drop"
    
  )


# =========================================================
# 13. SPARSE WEEKLY PROFILE
# =========================================================

sparse_profile <- weekly_sparse %>%
  
  group_by(
    canonical_name
  ) %>%
  
  summarise(
    
    total_usable_weeks_sparse =
      n(),
    
    latest_sparse_week =
      max(
        week_start,
        na.rm = TRUE
      ),
    
    latest_sparse_price =
      weekly_median[
        which.max(
          week_start
        )
      ],
    
    latest_sparse_active_days =
      active_days[
        which.max(
          week_start
        )
      ],
    
    .groups = "drop"
    
  )


# =========================================================
# 14. COMBINE PROFILES
# =========================================================

fish_profile <- master_fish %>%
  
  left_join(
    fish_raw_profile,
    by = "canonical_name"
  ) %>%
  
  left_join(
    dense_profile,
    by = "canonical_name"
  ) %>%
  
  left_join(
    sparse_profile,
    by = "canonical_name"
  )


# =========================================================
# 15. HANDLE MISSING VALUES
# =========================================================

fish_profile <- fish_profile %>%
  
  mutate(
    
    total_daily_observations =
      replace_na(
        total_daily_observations,
        0
      ),
    
    total_usable_weeks_dense =
      replace_na(
        total_usable_weeks_dense,
        0
      ),
    
    weeks_5plus_days_dense =
      replace_na(
        weeks_5plus_days_dense,
        0
      ),
    
    total_usable_weeks_sparse =
      replace_na(
        total_usable_weeks_sparse,
        0
      )
    
  )


# =========================================================
# 16. DATA FRESHNESS
# =========================================================

fish_profile <- fish_profile %>%
  
  mutate(
    
    days_since_latest_observation =
      
      case_when(
        
        total_daily_observations == 0
        ~ Inf,
        
        TRUE
        ~ as.integer(
          latest_source_date -
            latest_observation_date
        )
        
      ),
    
    freshness_status =
      
      case_when(
        
        total_daily_observations == 0
        ~ "NO_DATA",
        
        days_since_latest_observation <= 7
        ~ "CURRENT",
        
        days_since_latest_observation <= 28
        ~ "RECENT",
        
        TRUE
        ~ "STALE"
        
      )
    
  )


# =========================================================
# 17. DATA DENSITY
# =========================================================

fish_profile <- fish_profile %>%
  
  mutate(
    
    data_density =
      
      case_when(
        
        total_usable_weeks_dense >= 40 &
          
          (
            weeks_5plus_days_dense /
              total_usable_weeks_dense
          ) >= 0.70
        
        ~ "DENSE",
        
        total_usable_weeks_sparse >= 20
        ~ "SPARSE",
        
        total_usable_weeks_dense > 0
        ~ "VERY_LIMITED",
        
        total_usable_weeks_sparse > 0
        ~ "VERY_LIMITED",
        
        TRUE
        ~ "NO_DATA"
        
      )
    
  )


# =========================================================
# 18. PREPARE DENSE MODEL RESULTS
# =========================================================

dense_model <- dense_results %>%
  
  select(
    
    canonical_name,
    
    dense_test_predictions =
      test_predictions,
    
    dense_evaluation_status =
      evaluation_status,
    
    dense_naive_mae =
      naive_mae,
    
    dense_ets_mae =
      ets_mae,
    
    dense_naive_rmse =
      naive_rmse,
    
    dense_ets_rmse =
      ets_rmse,
    
    dense_naive_mape =
      naive_mape,
    
    dense_ets_mape =
      ets_mape,
    
    dense_ets_interval_coverage =
      ets_interval_coverage,
    
    dense_ets_interval_width =
      ets_interval_width
    
  )


# =========================================================
# 19. PREPARE SPARSE MODEL RESULTS
# =========================================================

sparse_model <- sparse_results %>%
  
  select(
    
    canonical_name,
    
    sparse_test_predictions =
      test_predictions,
    
    sparse_evaluation_status =
      evaluation_status,
    
    sparse_naive_mae =
      naive_mae,
    
    sparse_ets_mae =
      ets_mae,
    
    sparse_naive_rmse =
      naive_rmse,
    
    sparse_ets_rmse =
      ets_rmse,
    
    sparse_naive_mape =
      naive_mape,
    
    sparse_ets_mape =
      ets_mape,
    
    sparse_ets_interval_coverage =
      ets_interval_coverage,
    
    sparse_ets_interval_width =
      ets_interval_width
    
  )


# =========================================================
# 20. JOIN MODEL RESULTS
# =========================================================

decision_table <- fish_profile %>%
  
  left_join(
    dense_model,
    by = "canonical_name"
  ) %>%
  
  left_join(
    sparse_model,
    by = "canonical_name"
  )


# =========================================================
# 21. SELECT CORRECT MODEL EVIDENCE
# =========================================================

decision_table <- decision_table %>%
  
  mutate(
    
    selected_test_predictions =
      
      case_when(
        
        data_density ==
          "DENSE"
        ~ dense_test_predictions,
        
        data_density ==
          "SPARSE"
        ~ sparse_test_predictions,
        
        TRUE
        ~ 0
        
      ),
    
    selected_evaluation_status =
      
      case_when(
        
        data_density ==
          "DENSE" &
          
          !is.na(
            dense_evaluation_status
          )
        
        ~ dense_evaluation_status,
        
        data_density ==
          "SPARSE" &
          
          !is.na(
            sparse_evaluation_status
          )
        
        ~ sparse_evaluation_status,
        
        TRUE
        ~ "NO_EVALUATION"
        
      ),
    
    selected_naive_mae =
      
      case_when(
        
        data_density ==
          "DENSE"
        ~ dense_naive_mae,
        
        data_density ==
          "SPARSE"
        ~ sparse_naive_mae,
        
        TRUE
        ~ NA_real_
        
      ),
    
    selected_ets_mae =
      
      case_when(
        
        data_density ==
          "DENSE"
        ~ dense_ets_mae,
        
        data_density ==
          "SPARSE"
        ~ sparse_ets_mae,
        
        TRUE
        ~ NA_real_
        
      ),
    
    selected_ets_rmse =
      
      case_when(
        
        data_density ==
          "DENSE"
        ~ dense_ets_rmse,
        
        data_density ==
          "SPARSE"
        ~ sparse_ets_rmse,
        
        TRUE
        ~ NA_real_
        
      ),
    
    selected_ets_mape =
      
      case_when(
        
        data_density ==
          "DENSE"
        ~ dense_ets_mape,
        
        data_density ==
          "SPARSE"
        ~ sparse_ets_mape,
        
        TRUE
        ~ NA_real_
        
      ),
    
    selected_ets_interval_coverage =
      
      case_when(
        
        data_density ==
          "DENSE"
        ~ dense_ets_interval_coverage,
        
        data_density ==
          "SPARSE"
        ~ sparse_ets_interval_coverage,
        
        TRUE
        ~ NA_real_
        
      ),
    
    selected_ets_interval_width =
      
      case_when(
        
        data_density ==
          "DENSE"
        ~ dense_ets_interval_width,
        
        data_density ==
          "SPARSE"
        ~ sparse_ets_interval_width,
        
        TRUE
        ~ NA_real_
        
      )
    
  )


# =========================================================
# 22. PREFERRED MODEL
# =========================================================

decision_table <- decision_table %>%
  
  mutate(
    
    preferred_model =
      
      case_when(
        
        is.na(
          selected_ets_mae
        )
        
        ~ "NONE",
        
        selected_ets_mae <
          selected_naive_mae
        
        ~ "ETS",
        
        TRUE
        ~ "NAIVE"
        
      )
    
  )


# =========================================================
# 23. INTERVAL QUALITY
# =========================================================

decision_table <- decision_table %>%
  
  mutate(
    
    interval_quality =
      
      case_when(
        
        is.na(
          selected_ets_interval_coverage
        )
        
        ~ "UNKNOWN",
        
        selected_ets_interval_coverage >= 70 &
          
          selected_ets_interval_coverage <= 90
        
        ~ "ACCEPTABLE",
        
        selected_ets_interval_coverage < 70
        
        ~ "LOW_COVERAGE",
        
        selected_ets_interval_coverage > 90
        
        ~ "HIGH_COVERAGE"
        
      )
    
  )


# =========================================================
# 24. FORECAST SUPPORT
# =========================================================

decision_table <- decision_table %>%
  
  mutate(
    
    forecast_support =
      
      case_when(
        
        freshness_status ==
          "NO_DATA"
        
        ~ "UNAVAILABLE",
        
        freshness_status ==
          "STALE"
        
        ~ "UNAVAILABLE",
        
        selected_test_predictions < 8
        
        ~ "UNAVAILABLE",
        
        data_density ==
          "DENSE" &
          
          selected_test_predictions >= 40
        
        ~ "STRONG",
        
        data_density ==
          "SPARSE" &
          
          selected_test_predictions >= 8
        
        ~ "SPARSE_SUPPORT",
        
        data_density ==
          "VERY_LIMITED"
        
        ~ "LIMITED",
        
        TRUE
        ~ "UNAVAILABLE"
        
      )
    
  )


# =========================================================
# 25. FINAL MODEL TO USE
# =========================================================

decision_table <- decision_table %>%
  
  mutate(
    
    model_to_use =
      
      case_when(
        
        forecast_support ==
          "UNAVAILABLE"
        
        ~ "NONE",
        
        preferred_model ==
          "ETS"
        
        ~ "ETS(A,N,N)",
        
        preferred_model ==
          "NAIVE"
        
        ~ "NAIVE",
        
        TRUE
        ~ "NONE"
        
      )
    
  )


# =========================================================
# 26. FINAL QUALITY STATUS
# =========================================================

decision_table <- decision_table %>%
  
  mutate(
    
    quality_status =
      
      case_when(
        
        forecast_support ==
          "STRONG" &
          
          model_to_use ==
          "ETS(A,N,N)" &
          
          interval_quality ==
          "ACCEPTABLE"
        
        ~ "VALID",
        
        forecast_support ==
          "STRONG" &
          
          model_to_use ==
          "NAIVE"
        
        ~ "VALID",
        
        forecast_support ==
          "SPARSE_SUPPORT"
        
        ~ "SPARSE_DATA",
        
        forecast_support ==
          "LIMITED"
        
        ~ "LIMITED",
        
        TRUE
        ~ "UNAVAILABLE"
        
      )
    
  )


# =========================================================
# 27. DECISION REASON
# =========================================================

decision_table <- decision_table %>%
  
  mutate(
    
    decision_reason =
      
      case_when(
        
        freshness_status ==
          "NO_DATA"
        
        ~ "No Selangor PriceCatcher observations.",
        
        freshness_status ==
          "STALE"
        
        ~ "Latest PriceCatcher observation is stale.",
        
        forecast_support ==
          "SPARSE_SUPPORT" &
          
          model_to_use ==
          "ETS(A,N,N)"
        
        ~ "Sparse but current data; ETS outperformed the naive benchmark.",
        
        forecast_support ==
          "SPARSE_SUPPORT" &
          
          model_to_use ==
          "NAIVE"
        
        ~ "Sparse but current data; naive benchmark outperformed ETS.",
        
        model_to_use ==
          "ETS(A,N,N)"
        
        ~ "ETS outperformed the naive benchmark in walk-forward testing.",
        
        model_to_use ==
          "NAIVE"
        
        ~ "Naive benchmark outperformed ETS in walk-forward testing.",
        
        TRUE
        ~ "Insufficient evidence."
        
      )
    
  )


# =========================================================
# 28. CURRENT PRODUCTION REFERENCE
# =========================================================

dense_reference <- weekly_dense %>%
  
  filter(
    week_start ==
      last_completed_week
  ) %>%
  
  select(
    
    canonical_name,
    
    completed_week_dense =
      week_start,
    
    reference_price_dense =
      weekly_median,
    
    reference_active_days_dense =
      active_days,
    
    reference_observation_count_dense =
      observation_count,
    
    reference_premise_count_dense =
      premise_count
    
  )


sparse_reference <- weekly_sparse %>%
  
  filter(
    week_start ==
      last_completed_week
  ) %>%
  
  select(
    
    canonical_name,
    
    completed_week_sparse =
      week_start,
    
    reference_price_sparse =
      weekly_median,
    
    reference_active_days_sparse =
      active_days,
    
    reference_observation_count_sparse =
      observation_count,
    
    reference_premise_count_sparse =
      premise_count
    
  )


decision_table <- decision_table %>%
  
  left_join(
    dense_reference,
    by = "canonical_name"
  ) %>%
  
  left_join(
    sparse_reference,
    by = "canonical_name"
  ) %>%
  
  mutate(
    
    completed_week =
      
      case_when(
        
        data_density ==
          "DENSE"
        
        ~ completed_week_dense,
        
        data_density ==
          "SPARSE"
        
        ~ completed_week_sparse,
        
        TRUE
        ~ as.Date(NA)
        
      ),
    
    reference_price =
      
      case_when(
        
        data_density ==
          "DENSE"
        
        ~ reference_price_dense,
        
        data_density ==
          "SPARSE"
        
        ~ reference_price_sparse,
        
        TRUE
        ~ NA_real_
        
      ),
    
    reference_active_days =
      
      case_when(
        
        data_density ==
          "DENSE"
        
        ~ reference_active_days_dense,
        
        data_density ==
          "SPARSE"
        
        ~ reference_active_days_sparse,
        
        TRUE
        ~ NA_real_
        
      ),
    
    reference_observation_count =
      
      case_when(
        
        data_density ==
          "DENSE"
        
        ~ reference_observation_count_dense,
        
        data_density ==
          "SPARSE"
        
        ~ reference_observation_count_sparse,
        
        TRUE
        ~ NA_real_
        
      ),
    
    reference_premise_count =
      
      case_when(
        
        data_density ==
          "DENSE"
        
        ~ reference_premise_count_dense,
        
        data_density ==
          "SPARSE"
        
        ~ reference_premise_count_sparse,
        
        TRUE
        ~ NA_real_
        
      )
    
  )


# =========================================================
# 29. SPARSE FALLBACK
# =========================================================

sparse_latest_available <- weekly_sparse %>%
  
  group_by(
    canonical_name
  ) %>%
  
  slice_max(
    order_by =
      week_start,
    n = 1,
    with_ties = FALSE
  ) %>%
  
  ungroup() %>%
  
  select(
    
    canonical_name,
    
    fallback_week =
      week_start,
    
    fallback_price =
      weekly_median,
    
    fallback_active_days =
      active_days,
    
    fallback_observation_count =
      observation_count,
    
    fallback_premise_count =
      premise_count
    
  )


decision_table <- decision_table %>%
  
  left_join(
    sparse_latest_available,
    by = "canonical_name"
  ) %>%
  
  mutate(
    
    completed_week =
      
      case_when(
        
        data_density ==
          "SPARSE" &
          
          is.na(
            completed_week
          )
        
        ~ fallback_week,
        
        TRUE
        ~ completed_week
        
      ),
    
    reference_price =
      
      case_when(
        
        data_density ==
          "SPARSE" &
          
          is.na(
            reference_price
          )
        
        ~ fallback_price,
        
        TRUE
        ~ reference_price
        
      ),
    
    reference_active_days =
      
      case_when(
        
        data_density ==
          "SPARSE" &
          
          is.na(
            reference_active_days
          )
        
        ~ fallback_active_days,
        
        TRUE
        ~ reference_active_days
        
      ),
    
    reference_observation_count =
      
      case_when(
        
        data_density ==
          "SPARSE" &
          
          is.na(
            reference_observation_count
          )
        
        ~ fallback_observation_count,
        
        TRUE
        ~ reference_observation_count
        
      ),
    
    reference_premise_count =
      
      case_when(
        
        data_density ==
          "SPARSE" &
          
          is.na(
            reference_premise_count
          )
        
        ~ fallback_premise_count,
        
        TRUE
        ~ reference_premise_count
        
      )
    
  ) %>%
  
  select(
    
    -fallback_week,
    -fallback_price,
    -fallback_active_days,
    -fallback_observation_count,
    -fallback_premise_count
    
  )


# =========================================================
# 30. REMOVE TEMPORARY COLUMNS
# =========================================================

decision_table <- decision_table %>%
  
  select(
    
    -completed_week_dense,
    -reference_price_dense,
    -reference_active_days_dense,
    -reference_observation_count_dense,
    -reference_premise_count_dense,
    
    -completed_week_sparse,
    -reference_price_sparse,
    -reference_active_days_sparse,
    -reference_observation_count_sparse,
    -reference_premise_count_sparse
    
  )


# =========================================================
# 31. FINAL FORECAST ELIGIBILITY
# =========================================================
#
# IMPORTANT FIX:
#
#   latest_week was an obsolete field.
#
#   latest_observation_date = latest raw PriceCatcher date
#   completed_week          = latest completed modelling week
#
# =========================================================

cat("\n========================================\n")
cat("FINAL FORECAST ELIGIBILITY\n")
cat("========================================\n\n")


print(
  
  decision_table %>%
    
    select(
      
      canonical_name,
      
      data_density,
      
      total_usable_weeks_dense,
      
      total_usable_weeks_sparse,
      
      weeks_5plus_days_dense,
      
      total_daily_observations,
      
      latest_observation_date,
      
      days_since_latest_observation,
      
      freshness_status,
      
      selected_test_predictions,
      
      selected_naive_mae,
      
      selected_ets_mae,
      
      preferred_model,
      
      selected_ets_interval_coverage,
      
      selected_ets_interval_width,
      
      interval_quality,
      
      model_to_use,
      
      quality_status,
      
      completed_week,
      
      reference_price,
      
      reference_active_days,
      
      reference_observation_count,
      
      decision_reason
      
    ) %>%
    
    arrange(
      canonical_name
    ),
  
  n = Inf
  
)


# =========================================================
# 32. MODEL TO USE COUNTS
# =========================================================

cat("\n========================================\n")
cat("MODEL TO USE COUNTS\n")
cat("========================================\n\n")


print(
  
  decision_table %>%
    
    count(
      model_to_use
    ) %>%
    
    arrange(
      desc(n)
    )
  
)


# =========================================================
# 33. QUALITY STATUS COUNTS
# =========================================================

cat("\n========================================\n")
cat("QUALITY STATUS COUNTS\n")
cat("========================================\n\n")


print(
  
  decision_table %>%
    
    count(
      quality_status
    ) %>%
    
    arrange(
      desc(n)
    )
  
)


# =========================================================
# 34. DATA DENSITY COUNTS
# =========================================================

cat("\n========================================\n")
cat("DATA DENSITY COUNTS\n")
cat("========================================\n\n")


print(
  
  decision_table %>%
    
    count(
      data_density
    ) %>%
    
    arrange(
      desc(n)
    )
  
)


# =========================================================
# 35. FORECASTABLE FISH
# =========================================================

cat("\n========================================\n")
cat("FORECASTABLE FISH\n")
cat("========================================\n\n")


print(
  
  decision_table %>%
    
    filter(
      
      quality_status %in%
        c(
          "VALID",
          "SPARSE_DATA"
        )
      
    ) %>%
    
    select(
      
      canonical_name,
      
      model_to_use,
      
      quality_status,
      
      data_density,
      
      completed_week,
      
      reference_price,
      
      reference_active_days,
      
      reference_observation_count,
      
      selected_test_predictions,
      
      selected_ets_interval_coverage,
      
      selected_ets_interval_width
      
    ) %>%
    
    arrange(
      canonical_name
    ),
  
  n = Inf
  
)


# =========================================================
# 36. UNAVAILABLE FISH
# =========================================================
#
# IMPORTANT FIX:
#
#   latest_week removed.
#   latest_observation_date is the appropriate raw-data
#   freshness field.
# =========================================================

cat("\n========================================\n")
cat("UNAVAILABLE FISH\n")
cat("========================================\n\n")


print(
  
  decision_table %>%
    
    filter(
      quality_status ==
        "UNAVAILABLE"
    ) %>%
    
    select(
      
      canonical_name,
      
      latest_observation_date,
      
      completed_week,
      
      freshness_status,
      
      data_density,
      
      model_to_use,
      
      decision_reason
      
    ) %>%
    
    arrange(
      canonical_name
    ),
  
  n = Inf
  
)


# =========================================================
# 37. REFERENCE PRICE VALIDATION
# =========================================================

forecastable_reference_check <-
  decision_table %>%
  
  filter(
    
    quality_status %in%
      c(
        "VALID",
        "SPARSE_DATA"
      )
    
  )


missing_reference_prices <-
  forecastable_reference_check %>%
  
  filter(
    
    is.na(
      reference_price
    )
    
  )


if (
  nrow(
    missing_reference_prices
  ) > 0
) {
  
  print(
    missing_reference_prices,
    n = Inf
  )
  
  stop(
    "Forecastable fish are missing reference prices."
  )
  
}


message(
  "\nReference price validation passed."
)


# =========================================================
# 38. FISH COUNT VALIDATION
# =========================================================

if (
  nrow(
    decision_table
  ) !=
  nrow(
    master_fish
  )
) {
  
  stop(
    paste(
      "Fish count mismatch. Expected",
      nrow(master_fish),
      "but found",
      nrow(decision_table)
    )
  )
  
}


message(
  "Fish count validation passed: ",
  nrow(
    decision_table
  )
)


# =========================================================
# 39. SAVE FINAL ELIGIBILITY TABLE
# =========================================================

output_file <- file.path(
  
  output_dir,
  
  "final_forecast_eligibility.csv"
  
)


write_csv(
  
  decision_table,
  
  output_file
  
)


# =========================================================
# 40. FINAL STATUS
# =========================================================

cat("\n========================================\n")
cat("FINAL ELIGIBILITY COMPLETE\n")
cat("========================================\n\n")


message(
  "Saved final eligibility table to: ",
  output_file
)


message(
  "Latest source date: ",
  latest_source_date
)


message(
  "Latest completed week: ",
  last_completed_week
)


message(
  "Total fish evaluated: ",
  nrow(
    decision_table
  )
)


message(
  "Forecastable fish: ",
  sum(
    decision_table$quality_status %in%
      c(
        "VALID",
        "SPARSE_DATA"
      )
  )
)


message(
  "Unavailable fish: ",
  sum(
    decision_table$quality_status ==
      "UNAVAILABLE"
  )
)

