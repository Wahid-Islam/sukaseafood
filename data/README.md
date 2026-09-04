# Data

Reference datasets used by SukaSeafood. **Do not commit secrets** here.

## OpenDOSM PriceCatcher

Place monthly extracts under `open_dosm/YYYY/`. The 2025 and 2026 folders
are on `origin/main`. Lookups sit in `open_dosm/` itself.

| File | Source |
| --- | --- |
| `lookup_item.csv` | https://storage.data.gov.my/pricecatcher/lookup_item.csv |
| `lookup_premise.csv` | https://storage.data.gov.my/pricecatcher/lookup_premise.csv |
| `2025/pricecatcher_YYYY-MM.csv` | https://storage.data.gov.my/pricecatcher/pricecatcher_YYYY-MM.csv |
| `2026/pricecatcher_YYYY-MM.csv` | same catalogue |

Then: `cd backend && python scripts/generate_observed_price_seed.py`

That writes `db/seed/12_observed_prices.sql` so the API can serve Selangor
medians without reading the raw CSVs at runtime.

## Licence note

OpenDOSM / data.gov.my terms apply. Use as **observed price context**, not as a nationally representative CPI.
