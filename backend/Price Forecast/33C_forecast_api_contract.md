# SukaSeafood — Step 33C: Forecast API Contract

## Purpose

This contract defines how the SukaSeafood backend exposes the production seafood price forecast to the frontend.

The frontend should consume forecast records through the backend API/database.
It should not run R, ETS, Naive forecasting, backtesting, or range calibration.

## Source of truth

The backend reads from:

- `price_forecast`
- `forecast_model_version`
- `seafood_item`
- `location`

The R forecasting pipeline produces the forecast records that are ingested into `price_forecast`.

## Recommended endpoint

### GET /api/seafood/{seafood_item_id}/forecast

Optional query parameters:

- `location_id`
- `weeks` (default 4)

The endpoint should return the latest active production forecast for the requested canonical seafood item and location.

## Response shape

Example:

```json
{
  "seafood_item_id": "UUID",
  "canonical_name": "Kembung / Pelaling",
  "display_name": "Kembung / Pelaling",
  "location": {
    "location_id": "UUID",
    "state_name": "Selangor"
  },
  "reference": {
    "week_start": "2026-08-17",
    "price": 15.90
  },
  "forecast": [
    {
      "forecast_week_start": "2026-08-24",
      "horizon_weeks": 1,
      "expected_price": 15.90,
      "lower_bound": 14.90,
      "upper_bound": 16.90,
      "outlook": "NO_STRONG_SIGNAL",
      "outlook_label": "Around current levels",
      "directional_outlook_label": "No strong directional signal",
      "quality_status": "VALID"
    }
  ],
  "model": {
    "model_version_id": "UUID",
    "version_name": "SukaSeafood Price Forecast Model Selection 2026-08-v1",
    "algorithm": "MODEL_SELECTION_V1"
  },
  "generated_at": "2026-08-31T00:00:00Z"
}
```

## API field rules

### Required frontend fields

The frontend normally needs:

- `canonical_name`
- `reference.price`
- `forecast[].forecast_week_start`
- `forecast[].expected_price`
- `forecast[].lower_bound`
- `forecast[].upper_bound`
- `forecast[].outlook`
- `forecast[].outlook_label`
- `forecast[].directional_outlook_label`
- `forecast[].quality_status`

### Backend/audit fields

Useful for debugging/admin:

- `seafood_item_id`
- `location_id`
- `model_version_id`
- `version_name`
- `model_used`
- `generated_at`
- `horizon_weeks`

Do not require the frontend to display all backend/audit fields.

## Direction semantics

`outlook` is the forecast-range interpretation:

- `LIKELY_INCREASE`
- `LIKELY_DECREASE`
- `NO_STRONG_SIGNAL`

`NO_STRONG_SIGNAL` is intentionally different from `STABLE`.

The frontend should not rename `NO_STRONG_SIGNAL` to `STABLE`.

Recommended UI label:

`No strong directional signal`

## Quality semantics

Valid production values:

- `VALID`
- `SPARSE_DATA`

`VALID` means the fish has stronger data support under the production eligibility rules.

`SPARSE_DATA` means a forecast can be shown, but the underlying recent PriceCatcher data is sparse.

The frontend should communicate this appropriately rather than presenting sparse forecasts as equally strong as dense-data forecasts.

## Price-range semantics

The forecast is a range-based outlook rather than an authoritative price.

For each forecast week:

- `expected_price` = model point estimate
- `lower_bound` = lower forecast boundary
- `upper_bound` = upper forecast boundary

The frontend should present these as an estimated range.

Example presentation:

> Expected around RM15.90/kg  
> Estimated range: RM14.90–RM16.90/kg

Avoid language such as:

> The price will be RM15.90/kg

## Data freshness

The backend should only expose active forecast rows associated with the latest valid production model version.

The backend should retain historical forecast rows for auditability rather than overwriting history without trace.

## Recommended ordering

Return forecast rows ordered by:

```text
forecast_week_start ASC
```

The first row is the nearest forecast week.

## Missing forecast behavior

### 404 — Seafood exists but no current forecast

Return:

```json
{
  "error": "FORECAST_UNAVAILABLE",
  "message": "No current forecast is available for this seafood item and location."
}
```

### 404 — Seafood item does not exist

Return:

```json
{
  "error": "SEAFOOD_NOT_FOUND",
  "message": "Seafood item was not found."
}
```

### 400 — Invalid location

Return:

```json
{
  "error": "INVALID_LOCATION",
  "message": "The requested location is not supported."
}
```

## Database lookup flow

The backend should resolve IDs in this order:

```text
seafood_item_id
    ↓
seafood_item
    ↓
location_id
    ↓
forecast_model_version_id
    ↓
price_forecast
```

Do not use the display name as the permanent foreign key.

## Forecast selection query concept

The query should conceptually:

1. Identify the requested `seafood_item_id`.
2. Identify the requested Selangor `location_id`.
3. Identify the latest active production `forecast_model_version`.
4. Select that model version's forecast rows.
5. Return the requested four forecast weeks.
6. Order ascending by `forecast_week_start`.

## Daily refresh workflow

The production refresh should be:

```text
New PriceCatcher daily release
        ↓
ETL / R forecasting pipeline
        ↓
Production forecast CSV
        ↓
Backend ingestion
        ↓
Resolve:
  seafood_item_id
  location_id
  forecast_model_version_id
  source_snapshot_id
        ↓
UPSERT price_forecast
        ↓
API automatically serves latest rows
        ↓
Frontend displays forecast
```

## Important implementation rule

The frontend must not calculate:

- forecast ranges
- model selection
- direction
- uncertainty
- confidence
- forecast dates

Those values are generated upstream and stored in the database.

The frontend is a presentation layer.

## Versioning

When the forecasting methodology materially changes, create a new `forecast_model_version`.

Examples:

- `2026-08-v1` — current production engine
- `2026-10-v2` — future revised engine

Historical forecasts should retain their original model-version reference.

## Example frontend card

```text
Kembung / Pelaling

Current reference price
RM15.90/kg

Next week
RM15.90/kg
Estimated range: RM14.90–RM16.90/kg

Outlook
No strong directional signal

Forecast quality
Validated

Last updated
31 Aug 2026
```

The exact visual design is a frontend decision.

## Backend responsibilities

The backend developer is responsible for:

1. Database ID resolution.
2. Forecast ingestion/upsert.
3. Source snapshot linkage.
4. Model-version linkage.
5. API response formatting.
6. Filtering to active/latest production forecasts.
7. Returning useful errors when forecasts are unavailable.

## ML/R responsibilities

The ML pipeline is responsible for:

1. Processing PriceCatcher data.
2. Cleaning and aggregating prices.
3. Selecting dense/sparse series.
4. Selecting the validated model per fish.
5. Generating point forecasts.
6. Generating forecast intervals.
7. Generating validated directional outlook.
8. Producing the production CSV.
9. Updating the model version when methodology changes.

## Frontend responsibilities

The frontend is responsible for:

1. Displaying current price.
2. Displaying the four-week range.
3. Displaying the directional label.
4. Displaying the quality status appropriately.
5. Linking the price view to the same canonical seafood item shown by WWF.
6. Clearly communicating that forecast values are estimates.

## Non-authoritative wording

Recommended:

> Forecasted price range

> Expected price

> Likely to increase

> No strong directional signal

Avoid:

> Official price

> Guaranteed price

> The price will be

> Government price

> Market price set by SukaSeafood

## Acceptance criteria

A forecast API integration is considered complete when:

- A canonical seafood item can be requested by `seafood_item_id`.
- The API returns four forecast weeks when a current forecast exists.
- Every forecast row contains expected price, lower bound and upper bound.
- Direction is returned separately from the price range.
- `NO_STRONG_SIGNAL` is preserved.
- Forecast model version is traceable.
- Source snapshot is traceable in the database.
- Historical forecast rows remain auditable.
- The frontend does not perform any ML calculations.
- R does not need to be installed on the frontend.
