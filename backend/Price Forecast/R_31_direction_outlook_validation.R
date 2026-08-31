# =========================================================
# SukaSeafood Price Forecasting
# Step 31 — Directional Outlook Validation
# =========================================================
#
# Purpose:
#   Validate whether we can provide a useful directional
#   outlook alongside the forecast price range.
#
# User-facing outcomes:
#
#   LIKELY_INCREASE
#   LIKELY_DECREASE
#   NO_STRONG_SIGNAL
#
# IMPORTANT:
#   We DO NOT force an UP/DOWN prediction.
#
# Direction is only called when the selected directional
# strategy demonstrates useful out-of-sample performance.
#
# Candidate directional strategies:
#
#   1. MODEL_POINT_DIRECTION
#      Direction implied by the model point forecast.
#
#   2. LAST_WEEK_MOMENTUM
#      Predict the next movement using the previous week's
#      movement.
#
#   3. FOUR_WEEK_MOMENTUM
#      Predict using the change over the previous four weeks.
#
#   4. FOUR_WEEK_MEDIAN_SIGNAL
#      Compare current price against the recent four-week
#      median.
#
# Actual movement is classified using a RM0.25 threshold.
#
# A directional call is considered correct only when the
# predicted direction matches the actual movement direction.
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
# 1. LOAD FINAL ELIGIBILITY
# =========================================================

eligibility <- read_csv(
  file.path(
    output_dir,
    "final_forecast_eligibility.csv"
  ),
  show_col_types = FALSE
)

# =========================================================
# 2. LOAD DENSE WEEKLY SERIES
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
# 3. LOAD SPARSE WEEKLY SERIES
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
# 4. LOAD WALK-FORWARD MODEL PREDICTIONS
# =========================================================

dense_prediction_file <- file.path(
  output_dir,
  "multi_fish_ets_backtest_predictions.csv"
)

if (
  !file.exists(
    dense_prediction_file
  )
) {
  
  stop(
    paste(
      "Required dense prediction file not found:",
      dense_prediction_file
    )
  )
  
}

dense_predictions <- read_csv(
  dense_prediction_file,
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
# 5. LOAD SPARSE MODEL PREDICTIONS
# =========================================================

sparse_predictions <- read_csv(
  file.path(
    output_dir,
    "sparse_fish_backtest_predictions.csv"
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

initial_training_size <- 12

movement_threshold <- 0.25

minimum_directional_calls <- 8

minimum_call_rate <- 20

minimum_directional_accuracy <- 55

# =========================================================
# 7. FORECASTABLE FISH
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
    quality_status
  ) %>%
  arrange(
    canonical_name
  )

cat("\n========================================\n")
cat("DIRECTIONAL OUTLOOK VALIDATION\n")
cat("========================================\n\n")

message(
  "Forecastable fish: ",
  nrow(
    forecastable
  )
)

message(
  "Meaningful movement threshold: RM",
  movement_threshold
)

# =========================================================
# 8. HELPER — CLASSIFY ACTUAL MOVEMENT
# =========================================================

classify_actual_direction <- function(
    change,
    threshold
) {
  
  case_when(
    
    change >
      threshold
    ~ "UP",
    
    change <
      -threshold
    ~ "DOWN",
    
    TRUE
    ~ "STABLE"
    
  )
  
}

# =========================================================
# 9. HELPER — CLASSIFY SIGNAL
# =========================================================

classify_signal <- function(
    change,
    threshold
) {
  
  case_when(
    
    change >
      threshold
    ~ "UP",
    
    change <
      -threshold
    ~ "DOWN",
    
    TRUE
    ~ "NO_SIGNAL"
    
  )
  
}

# =========================================================
# 10. BUILD DIRECTIONAL TEST DATA
# =========================================================
#
# We construct all candidate directional rules using only
# information available before each test week.
#
# This prevents future information leakage.
# =========================================================

all_direction_results <- list()

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
  # Select correct historical series
  # -------------------------------------------------------
  
  if (
    density ==
    "DENSE"
  ) {
    
    fish_data <- weekly_dense %>%
      filter(
        canonical_name ==
          fish
      ) %>%
      arrange(
        week_start
      )
    
  } else {
    
    fish_data <- weekly_sparse %>%
      filter(
        canonical_name ==
          fish
      ) %>%
      arrange(
        week_start
      )
    
  }
  
  # -------------------------------------------------------
  # Remove incomplete/current week
  # -------------------------------------------------------
  
  if (
    nrow(
      fish_data
    ) < 20
  ) {
    
    next
    
  }
  
  max_completed_week <-
    max(
      eligibility$completed_week,
      na.rm = TRUE
    )
  
  fish_data <- fish_data %>%
    filter(
      week_start <=
        max_completed_week
    )
  
  total_weeks <-
    nrow(
      fish_data
    )
  
  if (
    total_weeks <=
    initial_training_size
  ) {
    
    next
    
  }
  
  # -------------------------------------------------------
  # Find corresponding model predictions
  # -------------------------------------------------------
  
  if (
    density ==
    "DENSE"
  ) {
    
    model_predictions <-
      dense_predictions %>%
      filter(
        canonical_name ==
          fish
      )
    
  } else {
    
    model_predictions <-
      sparse_predictions %>%
      filter(
        canonical_name ==
          fish
      )
    
  }
  
  # -------------------------------------------------------
  # Walk forward
  # -------------------------------------------------------
  
  fish_direction_results <- list()
  
  for (
    test_index in
    (
      initial_training_size + 1
    ):total_weeks
  ) {
    
    current_price <-
      fish_data$weekly_median[
        test_index - 1
      ]
    
    actual_price <-
      fish_data$weekly_median[
        test_index
      ]
    
    current_week <-
      fish_data$week_start[
        test_index - 1
      ]
    
    test_week <-
      fish_data$week_start[
        test_index
      ]
    
    actual_change <-
      actual_price -
      current_price
    
    actual_direction <-
      classify_actual_direction(
        actual_change,
        movement_threshold
      )
    
    # -----------------------------------------------------
    # Last-week momentum
    # -----------------------------------------------------
    
    if (
      test_index >= 3
    ) {
      
      previous_change <-
        fish_data$weekly_median[
          test_index - 1
        ] -
        fish_data$weekly_median[
          test_index - 2
        ]
      
    } else {
      
      previous_change <-
        NA_real_
      
    }
    
    last_week_signal <-
      classify_signal(
        previous_change,
        movement_threshold
      )
    
    # -----------------------------------------------------
    # Four-week momentum
    # -----------------------------------------------------
    
    if (
      test_index >= 6
    ) {
      
      four_week_change <-
        fish_data$weekly_median[
          test_index - 1
        ] -
        fish_data$weekly_median[
          test_index - 5
        ]
      
    } else {
      
      four_week_change <-
        NA_real_
      
    }
    
    four_week_signal <-
      classify_signal(
        four_week_change,
        movement_threshold
      )
    
    # -----------------------------------------------------
    # Four-week median signal
    # -----------------------------------------------------
    
    if (
      test_index >= 5
    ) {
      
      recent_four_week_median <-
        median(
          fish_data$weekly_median[
            (test_index - 4):
              (test_index - 1)
          ],
          na.rm = TRUE
        )
      
      median_deviation <-
        current_price -
        recent_four_week_median
      
    } else {
      
      median_deviation <-
        NA_real_
      
    }
    
    four_week_median_signal <-
      classify_signal(
        median_deviation,
        movement_threshold
      )
    
    # -----------------------------------------------------
    # Model point-direction signal
    # -----------------------------------------------------
    
    model_row <-
      model_predictions %>%
      filter(
        week_start ==
          test_week
      )
    
    model_signal <- "NO_SIGNAL"
    
    model_change <- NA_real_
    
    if (
      nrow(
        model_row
      ) == 1
    ) {
      
      if (
        selected_model ==
        "ETS(A,N,N)"
      ) {
        
        if (
          "current_price" %in%
          names(
            model_row
          ) &
          "ets_prediction" %in%
          names(
            model_row
          )
        ) {
          
          model_change <-
            model_row$ets_prediction -
            model_row$current_price
          
          model_signal <-
            classify_signal(
              model_change,
              movement_threshold
            )
          
        }
        
      } else {
        
        # Naive point prediction is the current price and
        # therefore contains no directional information.
        model_change <- 0
        model_signal <- "NO_SIGNAL"
        
      }
      
    }
    
    # -----------------------------------------------------
    # Store
    # -----------------------------------------------------
    
    fish_direction_results[[
      length(
        fish_direction_results
      ) + 1
    ]] <- tibble(
      
      canonical_name =
        fish,
      
      density =
        density,
      
      selected_model =
        selected_model,
      
      current_week =
        current_week,
      
      test_week =
        test_week,
      
      current_price =
        current_price,
      
      actual_price =
        actual_price,
      
      actual_change =
        actual_change,
      
      actual_direction =
        actual_direction,
      
      model_change =
        model_change,
      
      model_signal =
        model_signal,
      
      last_week_signal =
        last_week_signal,
      
      four_week_signal =
        four_week_signal,
      
      four_week_median_signal =
        four_week_median_signal
      
    )
    
  }
  
  all_direction_results[[
    length(
      all_direction_results
    ) + 1
  ]] <-
    bind_rows(
      fish_direction_results
    )
  
}

direction_results <-
  bind_rows(
    all_direction_results
  ) %>%
  arrange(
    canonical_name,
    test_week
  )

# =========================================================
# 11. EVALUATE CANDIDATE STRATEGIES
# =========================================================

evaluate_strategy <- function(
    data,
    signal_column
) {
  
  candidate <- data %>%
    mutate(
      signal =
        .data[[signal_column]]
    )
  
  directional_calls <-
    candidate %>%
    filter(
      signal %in%
        c(
          "UP",
          "DOWN"
        )
    )
  
  total_observations <-
    nrow(
      candidate
    )
  
  directional_predictions <-
    nrow(
      directional_calls
    )
  
  if (
    directional_predictions ==
    0
  ) {
    
    return(
      tibble(
        
        total_observations =
          total_observations,
        
        directional_predictions =
          0,
        
        call_rate =
          0,
        
        directional_accuracy =
          NA_real_
        
      )
    )
    
  }
  
  correct_predictions <-
    sum(
      directional_calls$signal ==
        directional_calls$actual_direction
    )
  
  tibble(
    
    total_observations =
      total_observations,
    
    directional_predictions =
      directional_predictions,
    
    call_rate =
      directional_predictions /
      total_observations *
      100,
    
    directional_accuracy =
      correct_predictions /
      directional_predictions *
      100
    
  )
  
}

# =========================================================
# 12. EVALUATE EACH FISH
# =========================================================

strategy_summary <- list()

strategy_names <- c(
  
  "model_signal",
  "last_week_signal",
  "four_week_signal",
  "four_week_median_signal"
  
)

for (
  fish in
  unique(
    direction_results$canonical_name
  )
) {
  
  fish_data <-
    direction_results %>%
    filter(
      canonical_name ==
        fish
    )
  
  for (
    strategy in
    strategy_names
  ) {
    
    stats <-
      evaluate_strategy(
        fish_data,
        strategy
      )
    
    strategy_summary[[
      length(
        strategy_summary
      ) + 1
    ]] <- tibble(
      
      canonical_name =
        fish,
      
      strategy =
        strategy,
      
      total_observations =
        stats$total_observations,
      
      directional_predictions =
        stats$directional_predictions,
      
      call_rate =
        stats$call_rate,
      
      directional_accuracy =
        stats$directional_accuracy
      
    )
    
  }
  
}

strategy_summary <-
  bind_rows(
    strategy_summary
  ) %>%
  arrange(
    canonical_name,
    desc(
      directional_accuracy
    )
  )

# =========================================================
# 13. PRINT STRATEGY PERFORMANCE
# =========================================================

cat("\n========================================\n")
cat("DIRECTION STRATEGY PERFORMANCE\n")
cat("========================================\n\n")

print(
  strategy_summary,
  n = Inf
)

# =========================================================
# 14. SELECT BEST STRATEGY PER FISH
# =========================================================
#
# Selection hierarchy:
#
#   1. Must have >=8 directional calls
#   2. Must have >=20% call rate
#   3. Prefer highest directional accuracy
#
# If no strategy passes those conditions:
#
#   NO_STRONG_SIGNAL
#
# We also require >=55% directional accuracy before allowing
# a production directional signal.
# =========================================================

strategy_summary <- strategy_summary %>%
  mutate(
    
    passes_minimum_evidence =
      directional_predictions >=
      minimum_directional_calls &
      call_rate >=
      minimum_call_rate &
      directional_accuracy >=
      minimum_directional_accuracy
    
  )

best_strategy <- strategy_summary %>%
  filter(
    passes_minimum_evidence
  ) %>%
  arrange(
    canonical_name,
    
    desc(
      directional_accuracy
    ),
    
    desc(
      call_rate
    )
  ) %>%
  group_by(
    canonical_name
  ) %>%
  slice_head(
    n = 1
  ) %>%
  ungroup()

# =========================================================
# 15. FISH WITHOUT A VALID DIRECTION STRATEGY
# =========================================================

all_fish <- forecastable %>%
  select(
    canonical_name,
    data_density,
    model_to_use,
    quality_status
  )

direction_selection <- all_fish %>%
  left_join(
    best_strategy %>%
      select(
        
        canonical_name,
        
        selected_strategy =
          strategy,
        
        directional_predictions,
        
        direction_call_rate =
          call_rate,
        
        directional_accuracy
        
      ),
    by =
      "canonical_name"
  ) %>%
  mutate(
    
    selected_strategy =
      replace_na(
        selected_strategy,
        "NO_STRONG_SIGNAL"
      ),
    
    direction_call_rate =
      replace_na(
        direction_call_rate,
        0
      )
    
  )

# =========================================================
# 16. USER-FACING DIRECTION LOGIC
# =========================================================
#
# For a selected strategy:
#
#   use the latest available signal.
#
# But if the latest observation has no signal, report:
#
#   NO_STRONG_SIGNAL
#
# We do NOT extrapolate a stale directional call.
# =========================================================

latest_signals <- direction_results %>%
  
  group_by(
    canonical_name
  ) %>%
  
  slice_max(
    order_by =
      test_week,
    
    n = 1,
    
    with_ties =
      FALSE
  ) %>%
  
  ungroup()

direction_selection <- direction_selection %>%
  left_join(
    latest_signals %>%
      select(
        
        canonical_name,
        
        latest_model_signal =
          model_signal,
        
        latest_last_week_signal =
          last_week_signal,
        
        latest_four_week_signal =
          four_week_signal,
        
        latest_four_week_median_signal =
          four_week_median_signal
        
      ),
    by =
      "canonical_name"
  )

# ---------------------------------------------------------
# Map selected strategy to latest signal
# ---------------------------------------------------------

direction_selection <- direction_selection %>%
  mutate(
    
    selected_latest_signal =
      case_when(
        
        selected_strategy ==
          "model_signal"
        ~ latest_model_signal,
        
        selected_strategy ==
          "last_week_signal"
        ~ latest_last_week_signal,
        
        selected_strategy ==
          "four_week_signal"
        ~ latest_four_week_signal,
        
        selected_strategy ==
          "four_week_median_signal"
        ~ latest_four_week_median_signal,
        
        TRUE
        ~ "NO_SIGNAL"
        
      )
    
  )

# =========================================================
# 17. USER-FACING OUTLOOK
# =========================================================

direction_selection <- direction_selection %>%
  mutate(
    
    outlook =
      case_when(
        
        selected_latest_signal ==
          "UP"
        ~ "LIKELY_INCREASE",
        
        selected_latest_signal ==
          "DOWN"
        ~ "LIKELY_DECREASE",
        
        TRUE
        ~ "NO_STRONG_SIGNAL"
        
      ),
    
    outlook_label =
      case_when(
        
        outlook ==
          "LIKELY_INCREASE"
        ~ "Likely to increase",
        
        outlook ==
          "LIKELY_DECREASE"
        ~ "Likely to decrease",
        
        TRUE
        ~ "No strong directional signal"
        
      )
    
  )

# =========================================================
# 18. PRINT FINAL DIRECTION DECISIONS
# =========================================================

cat("\n========================================\n")
cat("FINAL DIRECTION STRATEGY SELECTION\n")
cat("========================================\n\n")

print(
  
  direction_selection %>%
    select(
      
      canonical_name,
      
      data_density,
      
      model_to_use,
      
      quality_status,
      
      selected_strategy,
      
      directional_predictions,
      
      direction_call_rate,
      
      directional_accuracy,
      
      selected_latest_signal,
      
      outlook,
      
      outlook_label
      
    ) %>%
    arrange(
      canonical_name
    ),
  
  n = Inf
  
)

# =========================================================
# 19. DIRECTION OUTLOOK COUNTS
# =========================================================

cat("\n========================================\n")
cat("DIRECTION OUTLOOK COUNTS\n")
cat("========================================\n\n")

print(
  
  direction_selection %>%
    count(
      outlook
    ) %>%
    arrange(
      desc(n)
    )
  
)

# =========================================================
# 20. STRATEGY COUNTS
# =========================================================

cat("\n========================================\n")
cat("SELECTED STRATEGY COUNTS\n")
cat("========================================\n\n")

print(
  
  direction_selection %>%
    count(
      selected_strategy
    ) %>%
    arrange(
      desc(n)
    )
  
)

# =========================================================
# 21. SAVE STRATEGY PERFORMANCE
# =========================================================

write_csv(
  
  strategy_summary,
  
  file.path(
    output_dir,
    "direction_strategy_performance.csv"
  )
  
)

# =========================================================
# 22. SAVE FINAL DIRECTION DECISIONS
# =========================================================

write_csv(
  
  direction_selection,
  
  file.path(
    output_dir,
    "final_direction_outlook.csv"
  )
  
)

# =========================================================
# 23. SAVE HISTORICAL DIRECTION PREDICTIONS
# =========================================================

write_csv(
  
  direction_results,
  
  file.path(
    output_dir,
    "direction_walk_forward_predictions.csv"
  )
  
)

# =========================================================
# 24. FINAL VALIDATION
# =========================================================

if (
  nrow(
    direction_selection
  ) !=
  nrow(
    forecastable
  )
) {
  
  stop(
    "Direction selection is missing one or more forecastable fish."
  )
  
}

message(
  "\nDirection validation completed."
)

message(
  "Forecastable fish evaluated: ",
  nrow(
    direction_selection
  )
)

message(
  "Strong directional signals available: ",
  sum(
    direction_selection$outlook %in%
      c(
        "LIKELY_INCREASE",
        "LIKELY_DECREASE"
      )
  )
)

message(
  "No strong directional signal: ",
  sum(
    direction_selection$outlook ==
      "NO_STRONG_SIGNAL"
  )
)

message(
  "\nSaved strategy performance to: ",
  file.path(
    output_dir,
    "direction_strategy_performance.csv"
  )
)

message(
  "Saved final direction decisions to: ",
  file.path(
    output_dir,
    "final_direction_outlook.csv"
  )
)

message(
  "Saved walk-forward direction predictions to: ",
  file.path(
    output_dir,
    "direction_walk_forward_predictions.csv"
  )
)
