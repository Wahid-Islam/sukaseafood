# =========================================================
# SukaSeafood Price Forecasting
# Step 28A — Recent Weekly Coverage Diagnostic
# =========================================================

library(tidyverse)
library(lubridate)

processed_dir <- "data/processed"

# =========================================================
# 1. LOAD CLEAN DAILY DATA
# =========================================================

daily <- read_csv(
  file.path(
    processed_dir,
    "multi_fish_selangor_daily.csv"
  ),
  show_col_types = FALSE
) %>%
  mutate(
    week_start =
      floor_date(
        date,
        unit = "week",
        week_start = 1
      )
  )

# =========================================================
# 2. FOCUS ON RECENT 2026 DATA
# =========================================================

recent <- daily %>%
  filter(
    date >= as.Date("2026-07-01")
  )

# =========================================================
# 3. WEEKLY COVERAGE BY FISH
# =========================================================

recent_weekly <- recent %>%
  group_by(
    canonical_name,
    week_start
  ) %>%
  summarise(
    
    active_days =
      n_distinct(
        date
      ),
    
    observations =
      sum(
        observation_count
      ),
    
    premise_days =
      sum(
        premise_count
      ),
    
    weekly_median =
      median(
        median_price,
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  ) %>%
  arrange(
    canonical_name,
    week_start
  )

# =========================================================
# 4. PRINT FULL RECENT COVERAGE
# =========================================================

cat("\n========================================\n")
cat("RECENT WEEKLY COVERAGE\n")
cat("========================================\n\n")

print(
  recent_weekly,
  n = Inf
)

# =========================================================
# 5. COVERAGE DISTRIBUTION BY FISH
# =========================================================

cat("\n========================================\n")
cat("RECENT ACTIVE-DAY DISTRIBUTION\n")
cat("========================================\n\n")

coverage_distribution <- recent_weekly %>%
  group_by(
    canonical_name
  ) %>%
  summarise(
    
    weeks =
      n(),
    
    weeks_1plus =
      sum(
        active_days >= 1
      ),
    
    weeks_3plus =
      sum(
        active_days >= 3
      ),
    
    weeks_5plus =
      sum(
        active_days >= 5
      ),
    
    weeks_7 =
      sum(
        active_days == 7
      ),
    
    average_active_days =
      mean(
        active_days
      ),
    
    maximum_active_days =
      max(
        active_days
      ),
    
    latest_week =
      max(
        week_start
      ),
    
    .groups = "drop"
    
  ) %>%
  arrange(
    canonical_name
  )

print(
  coverage_distribution,
  n = Inf
)

# =========================================================
# 6. FOCUS ON PREVIOUSLY LIMITED FISH
# =========================================================

limited_fish <- c(
  "Bawal Hitam",
  "Ikan Merah",
  "Jenahak",
  "Siakap Putih",
  "Tenggiri"
)

cat("\n========================================\n")
cat("PREVIOUSLY LIMITED FISH — RECENT COVERAGE\n")
cat("========================================\n\n")

print(
  
  recent_weekly %>%
    filter(
      canonical_name %in%
        limited_fish
    ) %>%
    arrange(
      canonical_name,
      week_start
    ),
  
  n = Inf
  
)

# =========================================================
# 7. SAVE
# =========================================================

write_csv(
  recent_weekly,
  file.path(
    processed_dir,
    "recent_multi_fish_weekly_coverage.csv"
  )
)

write_csv(
  coverage_distribution,
  file.path(
    processed_dir,
    "recent_multi_fish_coverage_distribution.csv"
  )
)

message(
  "\nSaved recent weekly coverage to: ",
  file.path(
    processed_dir,
    "recent_multi_fish_weekly_coverage.csv"
  )
)

message(
  "Saved coverage distribution to: ",
  file.path(
    processed_dir,
    "recent_multi_fish_coverage_distribution.csv"
  )
)
