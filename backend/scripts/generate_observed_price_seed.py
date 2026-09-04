#!/usr/bin/env python3
"""Roll OpenDOSM PriceCatcher CSVs into db/seed/12_observed_prices.sql.

    cd backend && python scripts/generate_observed_price_seed.py

Reads monthly extracts under data/open_dosm/2025 and data/open_dosm/2026,
keeps only the catalogue item codes, and aggregates Selangor observations
into weekly trend points plus one latest-month summary per species.

DISPLAYABLE requires at least 10 observations, 3 premises and 5 distinct
days in the period. Anything thinner is stored as INSUFFICIENT_DATA so the
API can still refuse to render a number.
"""

from __future__ import annotations

import csv
import statistics
import sys
from collections import defaultdict
from datetime import date, datetime
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOSM = ROOT / "data" / "open_dosm"
OUT_PATH = ROOT / "backend" / "db" / "seed" / "12_observed_prices.sql"

SNAPSHOT = "pricecatcher-2025-01--2026-08"
CALC_VERSION = "opendosm-selangor-v1"

# Catalogue fish → PriceCatcher item codes (fresh 1kg listings only).
ITEM_MAP: dict[str, list[tuple[str, str, str]]] = {
    # code, mapping_type, notes
    "SF001": [
        ("55", "EXACT", "IKAN KEMBUNG KECIL/PELALING"),
        ("1476", "MARKET_VARIANT", "IKAN KEMBUNG"),
    ],
    "SF002": [("43", "EXACT", "IKAN BAWAL HITAM")],
    "SF003": [
        ("60", "COMMON_NAME", "IKAN MERAH whole"),
        ("1554", "MARKET_VARIANT", "IKAN MERAH kepingan"),
    ],
    "SF004": [
        ("89", "COMMON_NAME", "IKAN TILAPIA HITAM"),
        ("1921", "MARKET_VARIANT", "IKAN TILAPIA MERAH"),
    ],
    "SF005": [
        ("65", "MARKET_GROUP", "Generic IKAN KERAPU; not species-resolved"),
    ],
    "SF006": [("1475", "COMMON_NAME", "IKAN BAWAL PUTIH")],
    "SF007": [("47", "EXACT", "IKAN CENCARU")],
    "SF008": [
        ("51", "EXACT", "IKAN JENAHAK"),
        ("1915", "MARKET_VARIANT", "IKAN JENAHAK kepingan"),
    ],
    "SF009": [("1436", "EXACT", "IKAN KERISI")],
    "SF010": [("70", "EXACT", "IKAN SELAR PELATA")],
    "SF011": [("69", "EXACT", "IKAN SELAR KUNING")],
    "SF012": [
        ("79", "MARKET_VARIANT", "IKAN TENGGIRI PAPAN"),
        ("82", "MARKET_VARIANT", "IKAN TENGGIRI BATANG"),
        ("1438", "MARKET_VARIANT", "IKAN TENGGIRI BATANG kepingan"),
    ],
    "SF013": [("1916", "EXACT", "IKAN DEMUDUK/CUPAK/CERMIN")],
    "SF014": [("1437", "COMMON_NAME", "IKAN SIAKAP")],
}

MONTH_DISPLAYABLE = (10, 3, 5)  # observations, premises, distinct days
WEEK_DISPLAYABLE = (5, 2, 2)


def sql_str(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def sql_num(value: float | Decimal) -> str:
    dec = Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return str(dec)


def parse_day(raw: str) -> date | None:
    """Accept ISO dates and Excel-style day/month values."""
    text = raw.strip()
    if not text:
        return None
    iso = text[:10]
    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d/%m/%y", "%m/%d/%Y"):
        try:
            sample = iso if fmt.startswith("%Y-%") else text
            return datetime.strptime(sample, fmt).date()
        except ValueError:
            continue
    return None


def week_start(day: date) -> date:
    return date.fromordinal(day.toordinal() - day.weekday())


def month_bounds(day: date) -> tuple[date, date]:
    start = day.replace(day=1)
    if start.month == 12:
        nxt = start.replace(year=start.year + 1, month=1)
    else:
        nxt = start.replace(month=start.month + 1)
    return start, date.fromordinal(nxt.toordinal() - 1)


def norm_code(value: str) -> str:
    text = (value or "").strip()
    if text.endswith(".0"):
        text = text[:-2]
    try:
        return str(int(float(text)))
    except ValueError:
        return text


def load_selangor_premises() -> set[str]:
    path = DOSM / "lookup_premise.csv"
    codes: set[str] = set()
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            if (row.get("state") or "").strip().lower() == "selangor":
                codes.add(norm_code(row.get("premise_code") or ""))
    if not codes:
        raise SystemExit(f"no Selangor premises in {path}")
    return codes


def load_items() -> dict[str, tuple[str, str, str]]:
    path = DOSM / "lookup_item.csv"
    wanted = {code for pairs in ITEM_MAP.values() for code, _, _ in pairs}
    found: dict[str, tuple[str, str, str]] = {}
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            code = norm_code(row.get("item_code") or "")
            if code in wanted:
                found[code] = (
                    row.get("item") or f"item {code}",
                    row.get("unit") or "1kg",
                    row.get("item_group") or "",
                )
    missing = wanted - set(found)
    if missing:
        raise SystemExit(f"lookup_item missing codes: {sorted(missing)}")
    return found


def item_to_fish() -> dict[str, str]:
    mapping: dict[str, str] = {}
    for fish, pairs in ITEM_MAP.items():
        for code, _, _ in pairs:
            mapping[code] = fish
    return mapping


def csv_files() -> list[Path]:
    files: list[Path] = []
    for year in ("2025", "2026"):
        folder = DOSM / year
        if folder.is_dir():
            files.extend(sorted(folder.glob("pricecatcher_*.csv")))
    if not files:
        raise SystemExit(f"no monthly PriceCatcher CSVs under {DOSM}/2025 or {DOSM}/2026")
    return files


class Bucket:
    __slots__ = ("prices", "premises", "days")

    def __init__(self) -> None:
        self.prices: list[float] = []
        self.premises: set[str] = set()
        self.days: set[date] = set()

    def add(self, price: float, premise: str, day: date) -> None:
        self.prices.append(price)
        self.premises.add(premise)
        self.days.add(day)

    def quality(self, thresholds: tuple[int, int, int]) -> str:
        obs, prem, days = thresholds
        if (
            len(self.prices) >= obs
            and len(self.premises) >= prem
            and len(self.days) >= days
        ):
            return "DISPLAYABLE"
        return "INSUFFICIENT_DATA"

    def stats(self) -> dict[str, float | int]:
        ordered = sorted(self.prices)
        return {
            "median": statistics.median(ordered),
            "mean": statistics.fmean(ordered),
            "min": ordered[0],
            "max": ordered[-1],
            "p25": statistics.quantiles(ordered, n=4)[0] if len(ordered) >= 4 else ordered[0],
            "p75": statistics.quantiles(ordered, n=4)[2] if len(ordered) >= 4 else ordered[-1],
            "n": len(ordered),
            "premises": len(self.premises),
            "days": len(self.days),
        }


def ingest() -> tuple[dict[tuple[str, date], Bucket], dict[tuple[str, date], Bucket]]:
    premises = load_selangor_premises()
    fish_of = item_to_fish()
    wanted = set(fish_of)
    weekly: dict[tuple[str, date], Bucket] = defaultdict(Bucket)
    monthly: dict[tuple[str, date], Bucket] = defaultdict(Bucket)

    for path in csv_files():
        print(f"  reading {path.name}", file=sys.stderr)
        with path.open(encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle)
            # Official extracts use date / premise_code / item_code / price.
            date_key = next(k for k in reader.fieldnames or [] if k.lower() in {"date", "date_captured"})
            premise_key = next(k for k in reader.fieldnames or [] if "premise" in k.lower())
            item_key = next(k for k in reader.fieldnames or [] if "item" in k.lower())
            price_key = next(k for k in reader.fieldnames or [] if k.lower() in {"price", "price_rm"})
            for row in reader:
                item = norm_code(row.get(item_key) or "")
                if item not in wanted:
                    continue
                premise = norm_code(row.get(premise_key) or "")
                if premise not in premises:
                    continue
                raw_price = (row.get(price_key) or "").strip()
                raw_date = (row.get(date_key) or "").strip()
                if not raw_price or not raw_date:
                    continue
                try:
                    price = float(raw_price)
                except ValueError:
                    continue
                day = parse_day(raw_date)
                if day is None:
                    continue
                if price <= 0:
                    continue
                fish = fish_of[item]
                weekly[(fish, week_start(day))].add(price, premise, day)
                monthly[(fish, month_bounds(day)[0])].add(price, premise, day)

    return weekly, monthly


def product_form(name: str) -> str:
    lowered = name.lower()
    if "keping" in lowered:
        return "CUT"
    return "WHOLE"


def render(
    items: dict[str, tuple[str, str, str]],
    weekly: dict[tuple[str, date], Bucket],
    monthly: dict[tuple[str, date], Bucket],
) -> str:
    item_values = []
    mapping_values = []
    for fish, pairs in ITEM_MAP.items():
        for i, (code, mapping_type, notes) in enumerate(pairs, start=1):
            name, unit, group = items[code]
            item_values.append(
                "  ("
                + ", ".join(
                    [
                        sql_str(code),
                        sql_str(name),
                        sql_str(unit),
                        sql_str("KG"),
                        sql_str(group or None),
                        sql_str("BARANGAN SEGAR"),
                        sql_str(product_form(name)),
                    ]
                )
                + ")"
            )
            mapping_values.append(
                "  ("
                + ", ".join(
                    [
                        sql_str(fish),
                        sql_str(code),
                        sql_str(mapping_type),
                        str(i),
                        "TRUE" if i == 1 else "FALSE",
                        "TRUE" if mapping_type == "MARKET_GROUP" else "FALSE",
                        sql_str("COMBINE"),
                        sql_str("HIGH" if mapping_type == "EXACT" else "MEDIUM"),
                        sql_str(notes),
                    ]
                )
                + ")"
            )

    month_rows = []
    # One MONTH summary per fish: the latest month that has any observations.
    latest_by_fish: dict[str, date] = {}
    for (fish, start), bucket in monthly.items():
        if not bucket.prices:
            continue
        latest_by_fish[fish] = max(latest_by_fish.get(fish, start), start)

    for fish, start in sorted(latest_by_fish.items()):
        bucket = monthly[(fish, start)]
        end = month_bounds(start)[1]
        stats = bucket.stats()
        quality = bucket.quality(MONTH_DISPLAYABLE)
        month_rows.append(
            "  ("
            + ", ".join(
                [
                    sql_str(fish),
                    sql_str("MONTH"),
                    sql_str(start.isoformat()),
                    sql_str(end.isoformat()),
                    sql_num(stats["median"]),
                    sql_num(stats["mean"]),
                    sql_num(stats["min"]),
                    sql_num(stats["max"]),
                    sql_num(stats["p25"]),
                    sql_num(stats["p75"]),
                    str(stats["n"]),
                    str(stats["premises"]),
                    str(stats["days"]),
                    sql_str(quality),
                ]
            )
            + ")"
        )

    week_rows = []
    for (fish, start), bucket in sorted(weekly.items()):
        if not bucket.prices:
            continue
        stats = bucket.stats()
        quality = bucket.quality(WEEK_DISPLAYABLE)
        week_rows.append(
            "  ("
            + ", ".join(
                [
                    sql_str(fish),
                    sql_str(start.isoformat()),
                    sql_num(stats["median"]),
                    str(stats["n"]),
                    str(stats["premises"]),
                    str(stats["days"]),
                    sql_str(quality),
                ]
            )
            + ")"
        )

    return f"""-- =========================================================
-- 12_observed_prices.sql   ** GENERATED FILE — DO NOT EDIT **
-- =========================================================
-- Regenerate with:  cd backend && python scripts/generate_observed_price_seed.py
--
-- Selangor weekly medians and latest-month summaries from OpenDOSM
-- PriceCatcher 2025-01 .. 2026-08. Observed prices only — not the R forecast.

BEGIN;

INSERT INTO source_snapshot (
  source_snapshot_id, data_source_id, version_label,
  source_period_start, source_period_end, retrieved_at, collection_method, manifest, notes
)
SELECT
  suka_uuid5('source_snapshot:opendosm_pricecatcher:{SNAPSHOT}'),
  suka_uuid5('data_source:opendosm_pricecatcher'),
  '{SNAPSHOT}',
  '2025-01-01'::date,
  '2026-08-31'::date,
  '2026-09-02T00:00:00+08:00'::timestamptz,
  'OFFICIAL_DOWNLOAD'::collection_method_enum,
  '{{"files": ["data/open_dosm/2025/*.csv", "data/open_dosm/2026/*.csv"]}}'::jsonb,
  'Selangor PriceCatcher observations rolled into weekly and monthly medians.'
ON CONFLICT (source_snapshot_id) DO UPDATE SET
  source_period_start = EXCLUDED.source_period_start,
  source_period_end   = EXCLUDED.source_period_end,
  retrieved_at        = EXCLUDED.retrieved_at,
  manifest            = EXCLUDED.manifest,
  notes               = EXCLUDED.notes;

INSERT INTO pricecatcher_item (
  pricecatcher_item_id, source_snapshot_id, external_item_code,
  official_item_name, unit_raw, unit_code, item_group, item_category,
  product_form, size_descriptor, active
)
SELECT
  suka_uuid5('pricecatcher_item:' || v.external_item_code),
  suka_uuid5('source_snapshot:opendosm_pricecatcher:{SNAPSHOT}'),
  v.external_item_code, v.official_item_name, v.unit_raw, v.unit_code,
  v.item_group, v.item_category, v.product_form::product_form_enum, NULL, TRUE
FROM (VALUES
{',\n'.join(item_values)}
) AS v(external_item_code, official_item_name, unit_raw, unit_code,
       item_group, item_category, product_form)
ON CONFLICT (pricecatcher_item_id) DO UPDATE SET
  official_item_name = EXCLUDED.official_item_name,
  unit_raw           = EXCLUDED.unit_raw,
  unit_code          = EXCLUDED.unit_code,
  item_group         = EXCLUDED.item_group,
  item_category      = EXCLUDED.item_category,
  product_form       = EXCLUDED.product_form,
  active             = TRUE;

INSERT INTO price_item_mapping (
  price_item_mapping_id, seafood_item_id, pricecatcher_item_id,
  mapping_type, priority, is_default_for_generic, requires_variant_confirmation,
  aggregation_rule, mapping_confidence, notes
)
SELECT
  suka_uuid5('price_item_mapping:' || v.code || ':' || v.external_item_code),
  suka_uuid5('seafood_item:' || v.code),
  suka_uuid5('pricecatcher_item:' || v.external_item_code),
  v.mapping_type::price_mapping_type_enum,
  v.priority::smallint,
  v.is_default_for_generic,
  v.requires_variant_confirmation,
  v.aggregation_rule::aggregation_rule_enum,
  v.mapping_confidence::mapping_confidence_enum,
  v.notes
FROM (VALUES
{',\n'.join(mapping_values)}
) AS v(code, external_item_code, mapping_type, priority, is_default_for_generic,
       requires_variant_confirmation, aggregation_rule, mapping_confidence, notes)
ON CONFLICT (price_item_mapping_id) DO UPDATE SET
  mapping_type                   = EXCLUDED.mapping_type,
  priority                       = EXCLUDED.priority,
  is_default_for_generic         = EXCLUDED.is_default_for_generic,
  requires_variant_confirmation  = EXCLUDED.requires_variant_confirmation,
  aggregation_rule               = EXCLUDED.aggregation_rule,
  mapping_confidence             = EXCLUDED.mapping_confidence,
  notes                          = EXCLUDED.notes;

INSERT INTO price_period_summary (
  price_period_summary_id, seafood_item_id, location_id, source_snapshot_id,
  location_level, period_type, period_start, period_end,
  median_price, average_price, min_price, max_price, p25_price, p75_price,
  observation_count, premise_count, distinct_day_count,
  quality_status, calculation_version, calculated_at
)
SELECT
  suka_uuid5('price_period_summary:' || v.code || ':Selangor:' || v.period_type || ':' || v.period_start),
  suka_uuid5('seafood_item:' || v.code),
  suka_uuid5('location:Selangor'),
  suka_uuid5('source_snapshot:opendosm_pricecatcher:{SNAPSHOT}'),
  'STATE'::location_level_enum,
  v.period_type::period_type_enum,
  v.period_start::date,
  v.period_end::date,
  v.median_price::numeric, v.average_price::numeric, v.min_price::numeric,
  v.max_price::numeric, v.p25_price::numeric, v.p75_price::numeric,
  v.observation_count::integer, v.premise_count::integer, v.distinct_day_count::integer,
  v.quality_status::price_quality_enum,
  '{CALC_VERSION}',
  '2026-09-02T00:00:00+08:00'::timestamptz
FROM (VALUES
{',\n'.join(month_rows)}
) AS v(code, period_type, period_start, period_end, median_price, average_price,
       min_price, max_price, p25_price, p75_price, observation_count,
       premise_count, distinct_day_count, quality_status)
ON CONFLICT (price_period_summary_id) DO UPDATE SET
  median_price        = EXCLUDED.median_price,
  average_price       = EXCLUDED.average_price,
  min_price           = EXCLUDED.min_price,
  max_price           = EXCLUDED.max_price,
  p25_price           = EXCLUDED.p25_price,
  p75_price           = EXCLUDED.p75_price,
  observation_count   = EXCLUDED.observation_count,
  premise_count       = EXCLUDED.premise_count,
  distinct_day_count  = EXCLUDED.distinct_day_count,
  quality_status      = EXCLUDED.quality_status,
  calculated_at       = EXCLUDED.calculated_at;

INSERT INTO price_trend_point (
  price_trend_point_id, seafood_item_id, location_id, source_snapshot_id,
  week_start, weekly_median_price, observation_count, premise_count, active_days,
  quality_status, calculation_version
)
SELECT
  suka_uuid5('price_trend_point:' || v.code || ':Selangor:' || v.week_start),
  suka_uuid5('seafood_item:' || v.code),
  suka_uuid5('location:Selangor'),
  suka_uuid5('source_snapshot:opendosm_pricecatcher:{SNAPSHOT}'),
  v.week_start::date,
  v.weekly_median_price::numeric,
  v.observation_count::integer,
  v.premise_count::integer,
  v.active_days::smallint,
  v.quality_status::price_quality_enum,
  '{CALC_VERSION}'
FROM (VALUES
{',\n'.join(week_rows)}
) AS v(code, week_start, weekly_median_price, observation_count,
       premise_count, active_days, quality_status)
ON CONFLICT (price_trend_point_id) DO UPDATE SET
  weekly_median_price = EXCLUDED.weekly_median_price,
  observation_count   = EXCLUDED.observation_count,
  premise_count       = EXCLUDED.premise_count,
  active_days         = EXCLUDED.active_days,
  quality_status      = EXCLUDED.quality_status;

COMMIT;
"""


def main() -> int:
    print("Aggregating Selangor PriceCatcher observations:", file=sys.stderr)
    items = load_items()
    weekly, monthly = ingest()
    latest: dict[str, date] = {}
    for (fish, start), bucket in monthly.items():
        if bucket.prices:
            latest[fish] = max(latest.get(fish, start), start)
    for fish, start in sorted(latest.items()):
        bucket = monthly[(fish, start)]
        print(
            f"  {fish} {start:%Y-%m} median={statistics.median(bucket.prices):.2f} "
            f"n={len(bucket.prices)} {bucket.quality(MONTH_DISPLAYABLE)}",
            file=sys.stderr,
        )
    OUT_PATH.write_text(render(items, weekly, monthly), encoding="utf-8")
    print(f"Wrote {OUT_PATH} ({len(weekly)} weekly points)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
