# =========================================================
# SukaSeafood Price Forecasting
# Step 27 — Multi-Fish Price Cleaning
# Revised Conservative Version
# =========================================================

library(tidyverse)
library(lubridate)

processed_dir <- "data/processed"
output_dir <- "outputs"

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# =========================================================
# 1. LOAD DAILY MULTI-FISH DATA
# =========================================================

daily <- read_csv(
  file.path(
    processed_dir,
    "multi_fish_selangor_daily.csv"
  ),
  show_col_types = FALSE
) %>%
  arrange(
    canonical_name,
    date
  )

# =========================================================
# 2. BUILD ROBUST FISH-LEVEL REFERENCE STATISTICS
#
# We use the 1st and 99th percentiles as a broad screening
# boundary rather than the IQR rule.
#
# This avoids the IQR=0 problem seen in Bawal Hitam and
# Ikan Gelama.
# =========================================================

fish_bounds <- daily %>%
  group_by(
    canonical_name
  ) %>%
  summarise(
    
    p01 =
      quantile(
        median_price,
        0.01,
        na.rm = TRUE
      ),
    
    p99 =
      quantile(
        median_price,
        0.99,
        na.rm = TRUE
      ),
    
    median_reference =
      median(
        median_price,
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  )

# =========================================================
# 3. IDENTIFY STATISTICAL CANDIDATES
# =========================================================

daily_flagged <- daily %>%
  left_join(
    fish_bounds,
    by = "canonical_name"
  ) %>%
  mutate(
    
    statistical_extreme =
      median_price < p01 |
      median_price > p99,
    
    # -----------------------------------------------------
    # High-confidence anomaly:
    #
    # extreme daily median AND very few observations
    # -----------------------------------------------------
    
    high_confidence_outlier =
      statistical_extreme &
      observation_count <= 5,
    
    # -----------------------------------------------------
    # Potential anomaly:
    #
    # extreme price but supported by >5 observations.
    #
    # We retain these for now.
    # -----------------------------------------------------
    
    potential_high_support_extreme =
      statistical_extreme &
      observation_count > 5,
    
    cleaning_action =
      case_when(
        
        high_confidence_outlier
        ~ "REMOVE",
        
        potential_high_support_extreme
        ~ "KEEP_FLAGGED",
        
        TRUE
        ~ "KEEP"
        
      )
    
  )

# =========================================================
# 4. OUTLIER SUMMARY
# =========================================================

outlier_summary <- daily_flagged %>%
  group_by(
    canonical_name
  ) %>%
  summarise(
    
    total_days =
      n(),
    
    statistical_extremes =
      sum(
        statistical_extreme
      ),
    
    high_confidence_outliers =
      sum(
        high_confidence_outlier
      ),
    
    high_support_extremes =
      sum(
        potential_high_support_extreme
      ),
    
    days_removed =
      sum(
        cleaning_action ==
          "REMOVE"
      ),
    
    days_kept_flagged =
      sum(
        cleaning_action ==
          "KEEP_FLAGGED"
      ),
    
    days_retained =
      sum(
        cleaning_action ==
          "KEEP"
      ),
    
    .groups = "drop"
    
  ) %>%
  arrange(
    desc(
      days_removed
    ),
    canonical_name
  )

# =========================================================
# 5. SHOW HIGH-CONFIDENCE REMOVALS
# =========================================================

high_confidence_removals <- daily_flagged %>%
  filter(
    cleaning_action ==
      "REMOVE"
  ) %>%
  select(
    
    canonical_name,
    date,
    median_price,
    
    observation_count,
    premise_count,
    
    p01,
    p99,
    
    cleaning_action
    
  ) %>%
  arrange(
    canonical_name,
    date
  )

# =========================================================
# 6. SHOW HIGH-SUPPORT EXTREMES
#
# These are NOT removed.
# =========================================================

high_support_extremes <- daily_flagged %>%
  filter(
    cleaning_action ==
      "KEEP_FLAGGED"
  ) %>%
  select(
    
    canonical_name,
    date,
    median_price,
    
    observation_count,
    premise_count,
    
    p01,
    p99,
    
    cleaning_action
    
  ) %>%
  arrange(
    canonical_name,
    date
  )

# =========================================================
# 7. CREATE CLEAN DAILY SERIES
#
# Only high-confidence anomalies are removed.
# =========================================================

daily_clean <- daily_flagged %>%
  filter(
    cleaning_action !=
      "REMOVE"
  ) %>%
  select(
    
    canonical_name,
    date,
    median_price,
    p25_price,
    p75_price,
    mean_price,
    observation_count,
    premise_count
    
  )

# =========================================================
# 8. BUILD WEEKLY CLEAN SERIES
# =========================================================

weekly_clean <- daily_clean %>%
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
      max(
        premise_count,
        na.rm = TRUE
      ),
    
    active_days =
      n_distinct(
        date
      ),
    
    .groups = "drop"
    
  ) %>%
  arrange(
    canonical_name,
    week_start
  )

# =========================================================
# 9. KEEP ADEQUATELY OBSERVED WEEKS
# =========================================================

weekly_model <- weekly_clean %>%
  filter(
    active_days >= 5,
    week_start >= as.Date("2025-01-06")
  )

# =========================================================
# 10. BEFORE / AFTER SUMMARY
# =========================================================

before_after <- daily %>%
  group_by(
    canonical_name
  ) %>%
  summarise(
    
    daily_days_before =
      n(),
    
    .groups = "drop"
    
  ) %>%
  left_join(
    
    daily_clean %>%
      group_by(
        canonical_name
      ) %>%
      summarise(
        
        daily_days_after =
          n(),
        
        .groups = "drop"
        
      ),
    
    by = "canonical_name"
    
  ) %>%
  mutate(
    
    daily_days_removed =
      daily_days_before -
      daily_days_after,
    
    retention_rate =
      daily_days_after /
      daily_days_before *
      100
    
  ) %>%
  arrange(
    canonical_name
  )

# =========================================================
# 11. WEEKLY COVERAGE
# =========================================================

weekly_coverage <- weekly_model %>%
  group_by(
    canonical_name
  ) %>%
  summarise(
    
    total_weeks =
      n(),
    
    weeks_5plus_days =
      sum(
        active_days >= 5
      ),
    
    first_week =
      min(
        week_start
      ),
    
    last_week =
      max(
        week_start
      ),
    
    median_weekly_price =
      median(
        weekly_median,
        na.rm = TRUE
      ),
    
    min_weekly_price =
      min(
        weekly_median,
        na.rm = TRUE
      ),
    
    max_weekly_price =
      max(
        weekly_median,
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  )

# =========================================================
# 12. PRINT RESULTS
# =========================================================

cat("\n========================================\n")
cat("CONSERVATIVE MULTI-FISH OUTLIER SUMMARY\n")
cat("========================================\n\n")

print(
  outlier_summary,
  n = Inf
)

cat("\n========================================\n")
cat("HIGH-CONFIDENCE REMOVALS\n")
cat("========================================\n\n")

print(
  high_confidence_removals,
  n = Inf
)

cat("\n========================================\n")
cat("HIGH-SUPPORT EXTREMES — RETAINED\n")
cat("========================================\n\n")

print(
  high_support_extremes,
  n = Inf
)

cat("\n========================================\n")
cat("BEFORE vs AFTER CLEANING\n")
cat("========================================\n\n")

print(
  before_after,
  n = Inf
)

cat("\n========================================\n")
cat("WEEKLY COVERAGE AFTER CLEANING\n")
cat("========================================\n\n")

print(
  weekly_coverage,
  n = Inf
)

# =========================================================
# 13. SAVE
# =========================================================

write_csv(
  outlier_summary,
  file.path(
    output_dir,
    "multi_fish_outlier_summary.csv"
  )
)

write_csv(
  high_confidence_removals,
  file.path(
    output_dir,
    "multi_fish_high_confidence_removals.csv"
  )
)

write_csv(
  high_support_extremes,
  file.path(
    output_dir,
    "multi_fish_high_support_extremes.csv"
  )
)

write_csv(
  before_after,
  file.path(
    output_dir,
    "multi_fish_cleaning_impact.csv"
  )
)

write_csv(
  daily_clean,
  file.path(
    processed_dir,
    "multi_fish_selangor_daily_clean.csv"
  )
)

write_csv(
  weekly_model,
  file.path(
    processed_dir,
    "multi_fish_selangor_weekly_clean.csv"
  )
)

message(
  "\nSaved conservative clean daily data to: ",
  file.path(
    processed_dir,
    "multi_fish_selangor_daily_clean.csv"
  )
)

message(
  "Saved conservative clean weekly data to: ",
  file.path(
    processed_dir,
    "multi_fish_selangor_weekly_clean.csv"
  )
)
