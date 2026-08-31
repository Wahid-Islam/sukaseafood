-- SukaSeafood V3 — post-apply verification.
-- Run after apply.sh. Every row should report PASS.

\echo
\echo === SukaSeafood V3 database verification ===
\echo

WITH expected(table_name) AS (
  VALUES ('location'),('seafood_item'),('seafood_alias'),('data_source'),
         ('source_snapshot'),('wwf_assessment'),('pricecatcher_item'),
         ('pricecatcher_premise'),('price_item_mapping'),('price_period_summary'),
         ('price_trend_point'),('forecast_model_version'),('price_forecast'),
         ('supply_landing_point'),('cooking_method'),('cooking_suitability'),
         ('cv_model_version'),('cv_class_mapping'),('recipe'),
         ('recipe_seafood_mapping'),('recipe_cooking_method'),('app_user')
),
found AS (
  SELECT e.table_name,
         (t.table_name IS NOT NULL) AS present
  FROM expected e
  LEFT JOIN information_schema.tables t
    ON t.table_schema = 'public' AND t.table_name = e.table_name
)
SELECT
  CASE WHEN COUNT(*) FILTER (WHERE NOT present) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  'domain + app_user tables'                                                    AS check_name,
  COUNT(*) FILTER (WHERE present) || '/' || COUNT(*) || ' present'              AS detail,
  COALESCE(string_agg(table_name, ', ') FILTER (WHERE NOT present), '-')        AS missing
FROM found;

SELECT
  CASE WHEN COUNT(*) = 11 THEN 'PASS' ELSE 'FAIL' END AS status,
  '11 enum types' AS check_name,
  COUNT(*) || '/11 present' AS detail
FROM pg_type
WHERE typnamespace = 'public'::regnamespace
  AND typtype = 'e'
  AND typname IN (
    'location_level_enum','seafood_alias_type_enum','collection_method_enum',
    'sustainability_rating_enum','product_form_enum','price_mapping_type_enum',
    'aggregation_rule_enum','mapping_confidence_enum','price_quality_enum',
    'period_type_enum','recipe_mapping_type_enum'
  );

SELECT
  CASE WHEN suka_uuid5('seafood_item:SF001') = 'ae00df08-2bc0-5341-97e5-93b8b45d450b'::uuid
       THEN 'PASS' ELSE 'FAIL' END AS status,
  'suka_uuid5 determinism' AS check_name,
  suka_uuid5('seafood_item:SF001')::text AS detail;

SELECT
  CASE WHEN COUNT(*) FILTER (WHERE level = 'STATE') = 16
        AND COUNT(*) FILTER (WHERE level = 'DISTRICT') > 100
       THEN 'PASS' ELSE 'CHECK' END AS status,
  'location seed' AS check_name,
  COUNT(*) FILTER (WHERE level = 'STATE') || ' states, ' ||
  COUNT(*) FILTER (WHERE level = 'DISTRICT') || ' districts' AS detail
FROM location;

SELECT
  -- Counts what exists rather than asserting a fixed number: the catalogue
  -- grows (5 at I1, 12 after the CV expansion) and a hardcoded count turns
  -- every expansion into a spurious FAIL. What must hold is that EVERY active
  -- species carries its V3 fields.
  CASE WHEN COUNT(*) >= 5
        AND COUNT(*) FILTER (WHERE fish_type IS NOT NULL AND description IS NOT NULL) = COUNT(*)
       THEN 'PASS' ELSE 'FAIL' END AS status,
  'canonical species (V3 fields)' AS check_name,
  string_agg(code || ' ' || display_name_en, ', ' ORDER BY code) AS detail
FROM seafood_item WHERE active;

SELECT
  CASE WHEN COUNT(*) >= 25 THEN 'PASS' ELSE 'CHECK' END AS status,
  'search aliases' AS check_name,
  COUNT(*) || ' aliases across ' || COUNT(DISTINCT seafood_item_id) || ' species' AS detail
FROM seafood_alias;

SELECT
  CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'CHECK' END AS status,
  'WWF assessments' AS check_name,
  COUNT(*) || ' rated; SF005 intentionally unrated (UNDETERMINED)' AS detail
FROM wwf_assessment;

SELECT
  CASE WHEN COUNT(*) >= 25 THEN 'PASS' ELSE 'CHECK' END AS status,
  'cooking suitability' AS check_name,
  COUNT(*) || ' rows across ' || COUNT(DISTINCT cooking_method_id) || ' methods' AS detail
FROM cooking_suitability;

SELECT
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  'no orphaned foreign keys' AS check_name,
  COUNT(*) || ' orphans' AS detail
FROM (
  SELECT 1 FROM seafood_alias a
    LEFT JOIN seafood_item s USING (seafood_item_id) WHERE s.seafood_item_id IS NULL
  UNION ALL
  SELECT 1 FROM cooking_suitability c
    LEFT JOIN cooking_method m USING (cooking_method_id) WHERE m.cooking_method_id IS NULL
  UNION ALL
  SELECT 1 FROM wwf_assessment w
    LEFT JOIN source_snapshot ss USING (source_snapshot_id) WHERE ss.source_snapshot_id IS NULL
) orphans;

SELECT
  CASE WHEN NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'price_summary'
  ) THEN 'PASS' ELSE 'FAIL' END AS status,
  'I1 price_summary removed' AS check_name,
  'price_period_summary is the V3 derived price layer' AS detail;

-- Confirms v3_forecast_contract.sql was applied, not just v3_initial_schema.sql.
-- Without these columns the forecast endpoint returns rows with no reference
-- price, horizon or quality flag, and the app cannot present a range at all.
SELECT
  CASE WHEN COUNT(*) = 7 THEN 'PASS' ELSE 'FAIL' END AS status,
  'forecast contract columns (33B)' AS check_name,
  COUNT(*) || '/7 present on price_forecast' AS detail
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'price_forecast'
  AND column_name IN (
    'source_snapshot_id','forecast_origin_date','horizon_weeks',
    'current_reference_price','range_outlook','quality_status','model_used'
  );

SELECT
  CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS status,
  'one active forecast model version' AS check_name,
  COALESCE(string_agg(version_name || ' (' || algorithm || ')', ', '), 'none') AS detail
FROM forecast_model_version WHERE active;

-- Four weeks per fish, or the app renders a short chart with no way to tell the
-- user weeks are missing. Direction is reported separately from the range: most
-- fish are NO_STRONG_SIGNAL, and that is the engine's honest answer.
SELECT
  CASE WHEN COUNT(*) > 0
        AND COUNT(*) FILTER (WHERE weeks <> 4) = 0
       THEN 'PASS' ELSE 'CHECK' END AS status,
  'forecast horizon per fish' AS check_name,
  COUNT(*) || ' fish, ' || COALESCE(SUM(weeks), 0) || ' rows; ' ||
  COUNT(*) FILTER (WHERE weeks <> 4) || ' incomplete' AS detail
FROM (
  SELECT pf.seafood_item_id, COUNT(*) AS weeks
  FROM price_forecast pf
  JOIN forecast_model_version mv USING (forecast_model_version_id)
  WHERE mv.active
  GROUP BY pf.seafood_item_id
) x;

SELECT
  CASE WHEN COUNT(*) FILTER (
         WHERE outlook IS NOT NULL
           AND outlook NOT IN ('LIKELY_INCREASE','LIKELY_DECREASE','NO_STRONG_SIGNAL')
       ) = 0
       AND COUNT(*) FILTER (WHERE source_snapshot_id IS NULL) = 0
       THEN 'PASS' ELSE 'FAIL' END AS status,
  'forecast outlook vocabulary + traceability' AS check_name,
  COUNT(*) FILTER (WHERE outlook = 'NO_STRONG_SIGNAL') || ' NO_STRONG_SIGNAL, ' ||
  COUNT(*) FILTER (WHERE outlook = 'LIKELY_INCREASE')  || ' LIKELY_INCREASE, ' ||
  COUNT(*) FILTER (WHERE outlook = 'LIKELY_DECREASE')  || ' LIKELY_DECREASE, ' ||
  COUNT(*) FILTER (WHERE source_snapshot_id IS NULL)   || ' untraceable' AS detail
FROM price_forecast pf
JOIN forecast_model_version mv USING (forecast_model_version_id)
WHERE mv.active;

\echo
\echo Empty by design until the ETL runs: pricecatcher_item, pricecatcher_premise,
\echo price_item_mapping, price_period_summary, price_trend_point,
\echo supply_landing_point, recipe*.
\echo Seeded: cv_model_version, cv_class_mapping (06), price_forecast and
\echo forecast_model_version (09).
\echo
