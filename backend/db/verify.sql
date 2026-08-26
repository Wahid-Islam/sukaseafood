-- SukaSeafood I1 — post-apply verification.
-- Run after apply.sh. Every row should report PASS.

\echo
\echo === SukaSeafood I1 database verification ===
\echo

WITH expected(table_name) AS (
  VALUES ('location'),('seafood_item'),('seafood_alias'),('data_source'),
         ('source_snapshot'),('wwf_assessment'),('pricecatcher_item'),
         ('price_item_mapping'),('price_summary'),('price_trend_point'),
         ('supply_landing_point'),('cooking_method'),('cooking_suitability'),
         ('cv_model_version'),('recipe'),('recipe_seafood_mapping'),
         ('recipe_cooking_method')
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
  '17 domain tables'                                                            AS check_name,
  COUNT(*) FILTER (WHERE present) || '/17 present'                              AS detail,
  COALESCE(string_agg(table_name, ', ') FILTER (WHERE NOT present), '-')        AS missing
FROM found;

SELECT
  CASE WHEN COUNT(*) = 8 THEN 'PASS' ELSE 'FAIL' END AS status,
  '8 enum types' AS check_name,
  COUNT(*) || '/8 present' AS detail
FROM pg_type
WHERE typnamespace = 'public'::regnamespace
  AND typtype = 'e'
  AND typname IN (
    'location_level_enum','seafood_alias_type_enum','collection_method_enum',
    'sustainability_rating_enum','product_form_enum','price_mapping_type_enum',
    'price_quality_enum','recipe_mapping_type_enum'
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
  CASE WHEN COUNT(*) = 5 THEN 'PASS' ELSE 'FAIL' END AS status,
  'canonical species' AS check_name,
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

\echo
\echo Empty by design until the ETL runs: pricecatcher_item, price_item_mapping,
\echo price_summary, price_trend_point, supply_landing_point, recipe*, cv_model_version.
\echo
