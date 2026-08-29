# Database Schema V3 contract

Canonical handoff for Firebase SQL Connect / Cloud SQL and the FastAPI domain.

Full rationale PDF (local/SharePoint):  
`docs/artefacts/SukaSeafood_V3_Database_Schema_Implementation_Guide.pdf`

## Rule

**Identify once, reuse everywhere.** `seafood_item_id` is the only application
canonical seafood ID. Never use PriceCatcher item codes, WWF source rows,
premise codes, or CV class labels as the product identity.

## Hub and spokes

```
seafood_item
  ├── seafood_alias
  ├── wwf_assessment              (1:N, context-dependent ratings)
  ├── price_item_mapping ──────── pricecatcher_item
  │                               pricecatcher_premise → location
  ├── price_period_summary        (keyed by seafood_item_id)
  ├── price_trend_point           (keyed by seafood_item_id)
  ├── price_forecast ──────────── forecast_model_version
  ├── cv_class_mapping ────────── cv_model_version
  ├── cooking_suitability ─────── cooking_method
  └── recipe_seafood_mapping ──── recipe
```

`supply_landing_point` stays independent of `seafood_item` (geographic landings,
not species-level).

## Implementation sources

| Layer | Path |
| --- | --- |
| SQL DDL | `backend/db/schema/v3_initial_schema.sql` |
| Indexes / `suka_uuid5` | `backend/db/schema/v3_functions_indexes.sql` |
| I1 → V3 upgrade | `backend/db/schema/v3_migrate_from_i1.sql` |
| Apply | `backend/db/apply.sh` |
| Firebase GraphQL mirror | `dataconnect/schema/schema.gql` |
| Alembic | `0003_v3_schema` |

## Integrity highlights

1. `seafood_item.code` UNIQUE; index `scientific_name_normalized`
2. `pricecatcher_item.external_item_code` UNIQUE
3. `pricecatcher_premise.external_premise_code` UNIQUE
4. `price_item_mapping` UNIQUE `(seafood_item_id, pricecatcher_item_id)`
5. `wwf_assessment` UNIQUE `(source_snapshot_id, source_record_key)`
6. `price_period_summary` UNIQUE `(seafood_item_id, location_id, period_type, period_start, period_end, calculation_version)`
7. `price_trend_point` UNIQUE `(seafood_item_id, location_id, week_start, calculation_version)`
8. `price_forecast` UNIQUE `(seafood_item_id, location_id, forecast_model_version_id, forecast_week_start)`
9. `cv_class_mapping` UNIQUE `(cv_model_version_id, model_class_label)`
10. Foreign keys use `ON DELETE RESTRICT` for master/source records
