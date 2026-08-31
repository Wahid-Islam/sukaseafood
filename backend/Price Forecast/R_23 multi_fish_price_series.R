# =========================================================
# SukaSeafood Price Forecasting
# Step 23 — Multi-Fish Selangor Price Series
# =========================================================

library(tidyverse)
library(lubridate)

raw_dir <- "data/raw"
lookup_dir <- "data/lookup"
processed_dir <- "data/processed"

dir.create(
  processed_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# =========================================================
# 1. LOAD FISH → PRICECATCHER MAPPING
# =========================================================

fish_mapping <- read_csv(
  file.path(
    lookup_dir,
    "price_forecast_fish_mapping.csv"
  ),
  show_col_types = FALSE
) %>%
  mutate(
    item_code =
      as.integer(
        pricecatcher_item_code
      )
  ) %>%
  select(
    canonical_name,
    item_code
  ) %>%
  distinct()

# ---------------------------------------------------------
# Validate mapping
# ---------------------------------------------------------

if (
  any(
    is.na(
      fish_mapping$canonical_name
    )
  )
) {
  
  stop(
    "Missing canonical fish name in mapping."
  )
  
}

if (
  any(
    is.na(
      fish_mapping$item_code
    )
  )
) {
  
  stop(
    "Missing PriceCatcher item code in mapping."
  )
  
}

if (
  anyDuplicated(
    fish_mapping %>%
    select(
      canonical_name,
      item_code
    )
  )
) {
  
  stop(
    "Duplicate canonical_name + item_code mapping."
  )
  
}

supported_codes <-
  sort(
    unique(
      fish_mapping$item_code
    )
  )

cat("\n========================================\n")
cat("SUPPORTED FISH MAPPING\n")
cat("========================================\n\n")

print(
  fish_mapping %>%
    arrange(
      canonical_name,
      item_code
    )
)

message(
  "\nUnique PriceCatcher item codes: ",
  length(
    supported_codes
  )
)

message(
  "Canonical fish: ",
  n_distinct(
    fish_mapping$canonical_name
  )
)

# =========================================================
# 2. LOAD PREMISE LOOKUP
# =========================================================

lookup_premise <- read_csv(
  file.path(
    lookup_dir,
    "lookup_premise.csv"
  ),
  show_col_types = FALSE
) %>%
  select(
    premise_code,
    premise,
    state,
    district,
    premise_type
  ) %>%
  distinct(
    premise_code,
    .keep_all = TRUE
  )

if (
  anyDuplicated(
    lookup_premise$premise_code
  )
) {
  
  stop(
    "Duplicate premise_code values found."
  )
  
}

# =========================================================
# 3. FIND RAW PRICECATCHER FILES
# =========================================================

raw_files <- list.files(
  raw_dir,
  pattern = "^pricecatcher_.*\\.csv$",
  recursive = TRUE,
  full.names = TRUE
) %>%
  sort()

if (
  length(raw_files) == 0
) {
  
  stop(
    "No PriceCatcher monthly files found."
  )
  
}

cat("\n========================================\n")
cat("RAW FILES FOUND\n")
cat("========================================\n\n")

message(
  "Monthly files found: ",
  length(
    raw_files
  )
)

# =========================================================
# 4. READ MONTHLY FILES
#
# We force date to CHARACTER so lubridate can parse every
# source format consistently.
# =========================================================

filtered_months <- list()

for (
  file in raw_files
) {
  
  message(
    "Reading: ",
    basename(file)
  )
  
  month_data <- read_csv(
    file,
    col_select = c(
      date,
      premise_code,
      item_code,
      price
    ),
    col_types = cols(
      date = col_character(),
      premise_code = col_integer(),
      item_code = col_integer(),
      price = col_double()
    ),
    show_col_types = FALSE,
    progress = FALSE
  )
  
  # -------------------------------------------------------
  # Filter immediately to supported fish
  # -------------------------------------------------------
  
  month_data <- month_data %>%
    filter(
      item_code %in%
        supported_codes
    )
  
  if (
    nrow(month_data) == 0
  ) {
    
    next
    
  }
  
  # -------------------------------------------------------
  # Parse all known PriceCatcher date formats
  #
  # Examples:
  # 2026-01-26
  # 8/1/26
  # 8/17/26
  #
  # We prioritise YMD then MDY then DMY.
  # -------------------------------------------------------
  
  month_data <- month_data %>%
    mutate(
      
      date =
        parse_date_time(
          date,
          orders = c(
            "ymd",
            "mdy",
            "dmy"
          ),
          quiet = TRUE
        ) %>%
        as.Date(),
      
      premise_code =
        as.integer(
          premise_code
        ),
      
      item_code =
        as.integer(
          item_code
        ),
      
      price =
        as.numeric(
          price
        )
      
    )
  
  filtered_months[[
    length(
      filtered_months
    ) + 1
  ]] <-
    month_data
  
  rm(
    month_data
  )
  
  gc()
  
}

# =========================================================
# 5. COMBINE
# =========================================================

prices <- bind_rows(
  filtered_months
)

rm(
  filtered_months
)

gc()

# =========================================================
# 6. VALIDATE DATES BEFORE DOING ANYTHING ELSE
# =========================================================

bad_dates <- prices %>%
  filter(
    is.na(date)
  )

if (
  nrow(bad_dates) > 0
) {
  
  warning(
    paste(
      "Unparsed dates:",
      nrow(bad_dates)
    )
  )
  
}

# Remove unparseable rows
prices <- prices %>%
  filter(
    !is.na(date),
    !is.na(item_code),
    !is.na(premise_code),
    !is.na(price)
  )

# ---------------------------------------------------------
# Explicit date sanity checks
# ---------------------------------------------------------

date_min <-
  min(
    prices$date
  )

date_max <-
  max(
    prices$date
  )

if (
  year(date_min) < 2025
) {
  
  stop(
    paste(
      "Invalid minimum date detected:",
      date_min
    )
  )
  
}

if (
  year(date_max) > 2026
) {
  
  stop(
    paste(
      "Invalid maximum date detected:",
      date_max
    )
  )
  
}

# =========================================================
# 7. JOIN CANONICAL FISH
# =========================================================

prices <- prices %>%
  left_join(
    fish_mapping,
    by = "item_code"
  )

if (
  any(
    is.na(
      prices$canonical_name
    )
  )
) {
  
  stop(
    "Some supported item codes failed canonical mapping."
  )
  
}

# =========================================================
# 8. JOIN PREMISE / LOCATION
# =========================================================

prices <- prices %>%
  left_join(
    lookup_premise,
    by = "premise_code"
  )

unmatched_premises <-
  prices %>%
  filter(
    is.na(state)
  ) %>%
  distinct(
    premise_code
  )

if (
  nrow(unmatched_premises) > 0
) {
  
  warning(
    paste(
      "Unmatched premise codes:",
      nrow(unmatched_premises)
    )
  )
  
}

# =========================================================
# 9. SELANGOR ONLY FOR THIS DEVELOPMENT STAGE
# =========================================================

selangor <- prices %>%
  filter(
    state == "Selangor"
  )

# =========================================================
# 10. RAW COVERAGE CHECK
# =========================================================

cat("\n========================================\n")
cat("MULTI-FISH SELANGOR RAW COVERAGE\n")
cat("========================================\n\n")

message(
  "Total supported observations: ",
  nrow(
    selangor
  )
)

message(
  "Date range: ",
  min(
    selangor$date
  ),
  " → ",
  max(
    selangor$date
  )
)

message(
  "Unique canonical fish: ",
  n_distinct(
    selangor$canonical_name
  )
)

cat("\nObservations by fish:\n")

fish_coverage <- selangor %>%
  group_by(
    canonical_name
  ) %>%
  summarise(
    
    observations =
      n(),
    
    first_date =
      min(
        date
      ),
    
    last_date =
      max(
        date
      ),
    
    distinct_dates =
      n_distinct(
        date
      ),
    
    distinct_premises =
      n_distinct(
        premise_code
      ),
    
    median_price =
      median(
        price,
        na.rm = TRUE
      ),
    
    p01 =
      quantile(
        price,
        0.01,
        na.rm = TRUE
      ),
    
    p99 =
      quantile(
        price,
        0.99,
        na.rm = TRUE
      ),
    
    min_price =
      min(
        price,
        na.rm = TRUE
      ),
    
    max_price =
      max(
        price,
        na.rm = TRUE
      ),
    
    .groups = "drop"
    
  ) %>%
  arrange(
    canonical_name
  )

print(
  fish_coverage,
  n = Inf
)

# =========================================================
# 11. DAILY CANONICAL-FISH SERIES
# =========================================================

daily <- selangor %>%
  group_by(
    canonical_name,
    date
  ) %>%
  summarise(
    
    median_price =
      median(
        price,
        na.rm = TRUE
      ),
    
    p25_price =
      quantile(
        price,
        0.25,
        na.rm = TRUE
      ),
    
    p75_price =
      quantile(
        price,
        0.75,
        na.rm = TRUE
      ),
    
    mean_price =
      mean(
        price,
        na.rm = TRUE
      ),
    
    observation_count =
      n(),
    
    premise_count =
      n_distinct(
        premise_code
      ),
    
    .groups = "drop"
    
  ) %>%
  arrange(
    canonical_name,
    date
  )

# =========================================================
# 12. WEEKLY CANONICAL-FISH SERIES
# =========================================================

weekly <- daily %>%
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
# 13. SAVE
# =========================================================

write_csv(
  daily,
  file.path(
    processed_dir,
    "multi_fish_selangor_daily.csv"
  )
)

write_csv(
  weekly,
  file.path(
    processed_dir,
    "multi_fish_selangor_weekly.csv"
  )
)

# =========================================================
# 14. WEEKLY COVERAGE CHECK
# =========================================================

cat("\n========================================\n")
cat("WEEKLY COVERAGE BY FISH\n")
cat("========================================\n\n")

weekly_coverage <- weekly %>%
  group_by(
    canonical_name
  ) %>%
  summarise(
    
    weeks =
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
    
  ) %>%
  arrange(
    canonical_name
  )

print(
  weekly_coverage,
  n = Inf
)

# =========================================================
# 15. FINAL SANITY CHECK
# =========================================================

if (
  max(selangor$date) <
  as.Date("2026-08-01")
) {
  
  stop(
    paste(
      "August 2026 data was not detected.",
      "Latest date found:",
      max(selangor$date)
    )
  )
  
}

cat("\n========================================\n")
cat("DATE VALIDATION PASSED\n")
cat("========================================\n\n")

message(
  "Earliest Selangor date: ",
  min(selangor$date)
)

message(
  "Latest Selangor date: ",
  max(selangor$date)
)

message(
  "Canonical fish detected: ",
  n_distinct(
    selangor$canonical_name
  )
)

message(
  "\nSaved daily series to: ",
  file.path(
    processed_dir,
    "multi_fish_selangor_daily.csv"
  )
)

message(
  "Saved weekly series to: ",
  file.path(
    processed_dir,
    "multi_fish_selangor_weekly.csv"
  )
)

