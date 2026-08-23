# Data

Reference datasets used by SukaSeafood. **Do not commit secrets** here.

## OpenDOSM PriceCatcher

Place extracts under `open_dosm/`:

| File | Source |
| --- | --- |
| `lookup_item.csv` | https://storage.data.gov.my/pricecatcher/lookup_item.csv |
| `lookup_premise.csv` | https://storage.data.gov.my/pricecatcher/lookup_premise.csv |
| `pricecatcher_YYYY-MM.csv` | https://storage.data.gov.my/pricecatcher/pricecatcher_YYYY-MM.csv |

Catalogue: https://open.dosm.gov.my/data-catalogue/pricecatcher

### Download (PowerShell)

```powershell
cd data/open_dosm
Invoke-WebRequest https://storage.data.gov.my/pricecatcher/lookup_item.csv -OutFile lookup_item.csv
Invoke-WebRequest https://storage.data.gov.my/pricecatcher/lookup_premise.csv -OutFile lookup_premise.csv
Invoke-WebRequest https://storage.data.gov.my/pricecatcher/pricecatcher_2026-08.csv -OutFile pricecatcher_2026-08.csv
```

Large monthly files are gitignored by default. Backend Iteration 1 ships **seeded observed prices** so the API runs without these CSVs.

## Licence note

OpenDOSM / data.gov.my terms apply. Use as **observed price context**, not as a nationally representative CPI.
