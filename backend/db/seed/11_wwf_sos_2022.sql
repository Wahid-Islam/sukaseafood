-- =========================================================
-- 11_wwf_sos_2022.sql   ** GENERATED FILE — DO NOT EDIT **
-- =========================================================
-- Regenerate with:  cd backend && python scripts/generate_wwf_context_seed.py
--
-- Source: data/wwf_save_our_seafood_2022_backend_enriched_latest.csv
-- A newer snapshot than wwf-sos-2026-handoff, so GET /seafood picks these
-- rows (most recent retrieved_at) without rewriting the original transcription.

BEGIN;

INSERT INTO source_snapshot (
  source_snapshot_id, data_source_id, version_label,
  source_period_start, source_period_end, retrieved_at, collection_method, manifest, notes
)
SELECT
  suka_uuid5('source_snapshot:wwf_sos:wwf-sos-2022-enriched-latest'),
  suka_uuid5('data_source:wwf_sos'),
  'wwf-sos-2022-enriched-latest',
  '2022-01-01'::date,
  '2022-12-31'::date,
  '2026-09-02T00:00:00+08:00'::timestamptz,
  'MANUAL_PDF_TRANSCRIPTION'::collection_method_enum,
  '{"files": ["wwf_save_our_seafood_2022_backend_enriched_latest.csv"]}'::jsonb,
  'Enriched WWF Save Our Seafood 2022 rows, including per-listing context copy.'
ON CONFLICT (source_snapshot_id) DO UPDATE SET
  retrieved_at = EXCLUDED.retrieved_at,
  manifest     = EXCLUDED.manifest,
  notes        = EXCLUDED.notes;

INSERT INTO wwf_assessment (
  wwf_assessment_id, seafood_item_id, source_snapshot_id, source_record_key,
  common_name_raw, secondary_common_name_raw, scientific_name_raw, rating,
  origin_raw, origin_code, production_type, production_method_raw,
  production_method_code, certification_raw, context, notes_raw
)
SELECT
  suka_uuid5('wwf_assessment:wwf-sos-2022-enriched-latest:' || v.source_record_key),
  suka_uuid5('seafood_item:' || v.code),
  suka_uuid5('source_snapshot:wwf_sos:wwf-sos-2022-enriched-latest'),
  v.source_record_key,
  v.common_name_raw, v.secondary_common_name_raw, v.scientific_name_raw,
  v.rating::sustainability_rating_enum,
  v.origin_raw, v.origin_code, v.production_type, v.production_method_raw,
  v.production_method_code, v.certification_raw, v.context, v.notes_raw
FROM (VALUES
  ('SF001', 'wwf-row-32', 'Kembung / Pelaling', 'Indian Mackerel', 'Rastrelliger kanagurta', 'REDUCE', 'Malaysia', 'MY', 'WILD', 'Purse seine (Wild caught)', 'PURSE_SEINE', NULL, 'WWF rates Malaysian Kembung / Pelaling caught using purse seine as Reduce. This schooling mackerel is an important small pelagic fish in Malaysian fisheries and also forms part of the marine food web as prey for larger predators. Purse seines can efficiently harvest large schools, making appropriate control of fishing effort important to prevent excessive pressure on the stock. Maintaining healthy populations is important both for the fishery and for the wider marine ecosystem.', 'A small schooling mackerel widely eaten in Malaysia, with oily flesh and a strong place in everyday local cuisine.'),
  ('SF002', 'wwf-row-14', 'Bawal Hitam', 'Black Pomfret', 'Parastromateus niger', 'REDUCE', 'Malaysia', 'MY', 'WILD', 'Trawl (Wild caught)', 'TRAWL', NULL, 'WWF rates Malaysian Bawal Hitam caught using trawl as Reduce. Bawal Hitam is a commercially important coastal fish found over continental shelf waters. Trawl fishing can catch a wide range of non-target fish and marine organisms alongside the target species and may disturb seabed habitats when the gear contacts the bottom. Managing fishing pressure and reducing unwanted catch are therefore important for improving the sustainability of this fishery.', 'A deep-bodied pomfret with a distinctive dark body, commonly sold in Malaysian seafood markets.'),
  ('SF003', 'wwf-row-26', 'Ikan Merah', 'Red Snapper', 'Lutjanus sebae', 'REDUCE', 'Malaysia (East Coast)', 'MY', 'WILD', 'Hook and line (Wild caught)', 'HOOK_AND_LINE', NULL, 'WWF rates Malaysian Ikan Merah caught using hook and line as Reduce. Ikan Merah is a reef-associated snapper that can be vulnerable to sustained fishing pressure because larger individuals take time to reach maturity and contribute significantly to reproduction. Hook-and-line fishing is relatively selective and generally causes little direct damage to seabed habitats, although maintaining healthy breeding populations and appropriate fishing pressure remains important for the long-term sustainability of the stock.', 'A red snapper associated with reefs and coastal waters, known for firm flesh and a bright reddish body.'),
  ('SF004', 'wwf-row-60', 'Tilapia', 'Tilapia', 'Oreochromis Niloticus', 'REDUCE', 'Malaysia', 'MY', 'FARMED', 'Cage/ Pond culture (Farmed)', 'AQUACULTURE', NULL, 'WWF provides two Malaysian tilapia assessments. The general Malaysian cage/pond-culture record is Reduce, while the Hulu Perak cage-culture record is Best Choice and ASC certified. The guide notes that ASC-certified tilapia is available from Tasik Temenggor, Perak. This illustrates that production location and responsible farming practices can materially change the sustainability assessment.', 'A hardy freshwater tilapia commonly farmed for its mild flavour, firm flesh and adaptable production conditions.'),
  ('SF005', 'wwf-row-34', 'Kerapu Bintik', 'Orange Spotted Grouper', 'Epinephelus coioides', 'AVOID', 'Malaysia', 'MY', 'WILD', 'Bottom Trawl (Wild caught)', 'TRAWL', NULL, 'WWF notes that Orange Spotted Grouper uses coastal habitats including mangroves, coral reefs, estuaries, shallow seas and saline lagoons. It is commonly caught by bottom trawl, which the guide describes as highly detrimental because the gear is non-selective, can damage habitat and can produce bycatch of endangered, threatened and protected species. The combined habitat and fishing-method risks support Avoid.', 'A reef-associated grouper found in tropical coastal waters, commonly sold as a premium food fish in Southeast Asia.'),
  ('SF006', 'wwf-row-15', 'Bawal Putih', 'Chinese Silver Pomfret', 'Pampus chinensis', 'AVOID', 'Malaysia', 'MY', 'WILD', 'Gillnets (Wild caught)', 'GILLNET', NULL, 'WWF notes that Chinese Silver Pomfret occurs seasonally, usually singly or in small schools over muddy bottoms, and may enter estuaries. The guide states that it is mainly caught by trawl and describes trawling as highly detrimental because it is non-selective, prone to habitat destruction and can create bycatch of endangered, threatened and protected species. These impacts support Avoid.', 'A silver-bodied pomfret found over muddy coastal seabeds and widely consumed across Asian markets.'),
  ('SF007', 'wwf-row-19', 'Cencaru', 'Hardtail Scad', 'Megalaspis cordyla', 'BEST_CHOICE', 'Malaysia', 'MY', 'WILD', 'Purse seine/ Gillnet Trawl (Wild caught)', 'PURSE_SEINE', NULL, 'WWF rates Malaysian Cencaru caught using purse seine, gillnets and trawl as Best Choice. Cencaru is a schooling coastal fish that is widely harvested in Malaysian waters. Purse seines can efficiently target schools in the water column, while gillnets and trawls have different levels of bycatch and habitat impact. Sustainability therefore depends on appropriate management of fishing effort, gear use and the condition of the stock. Under the fisheries assessed by WWF, this source is considered a preferred seafood choice.', 'A robust coastal scad that forms schools in tropical waters and is a familiar fish in Malaysian markets.'),
  ('SF008', 'wwf-row-29', 'Jenahak', 'John''s Snapper', 'Lutjanus johnii', 'AVOID', 'Malaysia', 'MY', 'WILD', 'Trawl (Wild caught)', 'TRAWL', NULL, 'WWF reports that no stock assessments are available for John''s Snapper and that the species is highly vulnerable to fishing pressure. Regional fisheries are considered significantly overfished, while bottom trawling can threaten turtles and damage corals and other benthic organisms. The guide also notes high catches of juveniles and non-target fish and insufficient information to judge management effectiveness. These factors support Avoid.', 'A snapper associated with coastal and reef habitats, recognised for its coppery-red body and firm flesh.'),
  ('SF009', 'wwf-row-43', 'Kerisi', 'Treadfin Breams', 'Nemipterus japiconus', 'REDUCE', 'Malaysia', 'MY', 'WILD', 'Trawl (Wild caught)', 'TRAWL', NULL, 'WWF rates Malaysian Kerisi caught using trawl as Reduce. Kerisi are bottom-associated fish commonly found over sandy and muddy substrates in coastal and offshore waters. Trawling operates directly within these habitats and can capture non-target species while disturbing seabed communities. Managing fishing effort, bycatch and habitat impacts is therefore important for improving the sustainability of this fishery.', 'A small to medium coastal bream found over sandy or muddy bottoms and widely represented in Asian fisheries.'),
  ('SF010', 'wwf-row-52', 'Pelata', 'Blackfin Scad', 'Alepes melanoptera', 'REDUCE', 'Malaysia', 'MY', 'WILD', 'Purse seine (Wild caught)', 'PURSE_SEINE', NULL, 'WWF rates Malaysian Pelata caught using purse seine as Reduce. Pelata is a small schooling fish found in coastal and offshore waters and forms part of the food supply for larger marine predators. Purse seines can efficiently harvest large schools with relatively little direct seabed impact, but excessive fishing can reduce the abundance of the target population. Appropriate control of fishing effort is therefore important for maintaining healthy stocks.', 'A small tropical scad that forms schools in coastal waters and is commonly caught by purse seine fisheries.'),
  ('SF011', 'wwf-row-53', 'Selar Kuning', 'Yellowtail Scad', 'Selaroides leptolepis', 'AVOID', 'Malaysia', 'MY', 'WILD', 'Demersal gillnets (Wild caught)', 'GILLNET', NULL, 'WWF calls this a very data-deficient fishery: the species'' biology and vulnerability to fishing mortality cannot be properly assessed. Given widespread overfishing in the Indo-Pacific and specifically Malaysia and Indonesia, the guide considers stocks likely to be overfished or undergoing overfishing. It also says bottom-set gillnets are non-selective and can have high impacts on endangered, threatened and protected species, supporting Avoid.', 'A small yellow-tailed scad associated with tropical coastal waters and commonly caught in nearshore fisheries.'),
  ('SF012', 'wwf-row-57', 'Tenggiri', 'Narrow-barred Spanish Mackerel', 'Scomberomorus commerson', 'REDUCE', 'Malaysia', 'MY', 'WILD', 'Hook and line (WIld caught)', 'HOOK_AND_LINE', NULL, 'WWF assesses the same Narrow-barred Spanish Mackerel species differently by fishing method. Hook-and-line is highly selective and has much lower bycatch and discard levels, so that record is Reduce; the gillnet record is Avoid. WWF also notes that the species is Near Threatened, stocks are not fully assessed across its range and catch data are limited. The method therefore materially affects the classification.', 'A large, fast-swimming mackerel with firm flesh, widely consumed in Malaysia and other tropical Asian markets.'),
  ('SF012', 'wwf-row-58', 'Tenggiri', 'Narrow-barred Spanish Mackerel', 'Scomberomorus commerson', 'AVOID', 'Malaysia', 'MY', 'WILD', 'Gillnets (Wild caught)', 'GILLNET', NULL, 'WWF assesses the same Narrow-barred Spanish Mackerel species differently by fishing method. Hook-and-line is highly selective and has much lower bycatch and discard levels, so that record is Reduce; the gillnet record is Avoid. WWF also notes that the species is Near Threatened, stocks are not fully assessed across its range and catch data are limited. The method therefore materially affects the classification.', 'A large, fast-swimming mackerel with firm flesh, widely consumed in Malaysia and other tropical Asian markets.'),
  ('SF014', 'wwf-row-55', 'Siakap Putih', 'Asian seabass / Barramundi', 'Lates calcarifer', 'AVOID', 'Malaysia', 'MY', 'FARMED', 'Pond culture (Farmed)', 'AQUACULTURE', NULL, 'WWF highlights risks in Malaysian barramundi pond farming including effects on soil fertility and salinisation of soil and water bodies. The guide also notes that some small Malaysian farms depend on trash fish, resulting in a high Fish Feed Dependency Ratio. Although pond systems can have lower disease risk than open cages, WWF still rates this record Avoid and points consumers to AIP alternatives.', 'A versatile Asian seabass found in estuaries, coastal waters and farms, known for its mild flavour and firm flesh.')
) AS v(code, source_record_key, common_name_raw, secondary_common_name_raw,
       scientific_name_raw, rating, origin_raw, origin_code, production_type,
       production_method_raw, production_method_code, certification_raw,
       context, notes_raw)
ON CONFLICT (wwf_assessment_id) DO UPDATE SET
  rating                     = EXCLUDED.rating,
  common_name_raw            = EXCLUDED.common_name_raw,
  secondary_common_name_raw  = EXCLUDED.secondary_common_name_raw,
  scientific_name_raw        = EXCLUDED.scientific_name_raw,
  origin_raw                 = EXCLUDED.origin_raw,
  origin_code                = EXCLUDED.origin_code,
  production_type            = EXCLUDED.production_type,
  production_method_raw      = EXCLUDED.production_method_raw,
  production_method_code     = EXCLUDED.production_method_code,
  certification_raw          = EXCLUDED.certification_raw,
  context                    = EXCLUDED.context,
  notes_raw                  = EXCLUDED.notes_raw;

COMMIT;
