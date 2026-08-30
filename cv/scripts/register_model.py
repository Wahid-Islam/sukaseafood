#!/usr/bin/env python3
"""Generate the SQL that registers a trained model with the database.

Why this is generated and not hand-written
------------------------------------------
The class order is frozen inside model.onnx. Index 3 means Cencaru because that
is the order the training run used, and nothing in the database can discover
that — it has to be told. A human editing an index list is one typo away from a
scanner that confidently names the wrong fish, with no error anywhere: the join
succeeds, the UUID is real, the profile renders. That failure is invisible, so
the mapping is derived from the artifact itself and never typed twice.

Output goes to backend/db/seed/06_cv_model_registration.sql rather than a
directory of its own, because the backend's seed loader applies every *.sql in
that folder in filename order. Putting it there means a fresh checkout, a CI
database and a teammate's laptop all come up with a working scanner instead of
a 503 that has to be diagnosed. It is the last seed file for a reason: it joins
to seafood_item rows that 04 and 05 create.

    python scripts/register_model.py                    # from cv/
    python scripts/register_model.py --check            # CI: fail if stale
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

CV_ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_HANDOFF = CV_ROOT / "handoff"
DEFAULT_OUT = CV_ROOT.parent / "backend" / "db" / "seed" / "06_cv_model_registration.sql"

HEADER = """\
-- =========================================================
-- 06_cv_model_registration.sql   ** GENERATED FILE — DO NOT EDIT **
-- =========================================================
-- Regenerate with:  cd cv && python scripts/register_model.py
--
-- Source of truth: cv/handoff/class_map.json and cv/handoff/model_card.json,
-- both written by scripts/export_onnx.py alongside the model.onnx they
-- describe. Editing this file by hand desynchronises it from the artifact the
-- server actually loads, and the resulting mislabelling produces no error —
-- only wrong fish.
--
-- Applied automatically by the backend seed loader (backend/app/seed), after
-- 04_seafood_i1.sql and 05_seafood_cv_expansion.sql, which create the
-- seafood_item rows this file joins to.
--
-- Invariants enforced at the bottom of this file:
--   * exactly one active cv_model_version, so the adapter and the resolution
--     query can never disagree about which class map applies
--   * one mapping per class the model emits, each pointing at a seafood_item
--     that exists and has supports_cv = TRUE
--   * no species advertised as scannable without a mapping to back it up
"""


def build_sql(class_map: dict, model_card: dict) -> str:
    version = class_map["model_version"]
    if model_card.get("model_version") != version:
        raise SystemExit(
            f"class_map.json says '{version}' but model_card.json says "
            f"'{model_card.get('model_version')}'. The handoff directory holds "
            f"two different models; re-export before registering."
        )

    classes = sorted(class_map["classes"], key=lambda c: c["class_index"])
    indices = [c["class_index"] for c in classes]
    if indices != list(range(len(classes))):
        raise SystemExit(
            f"class indices are not 0..{len(classes) - 1} with no gaps: {indices}. "
            f"The argmax the adapter takes would not address these rows."
        )

    threshold = float(model_card.get("confidence_threshold", 0.5))
    metrics = model_card.get("metrics", {})

    # Register the held-out test figure, not the validation figure. Validation
    # steered the training run, so quoting it to a stakeholder overstates what
    # the model does on images it has never influenced.
    splits = {s["split"]: s for s in metrics.get("splits", [])}
    test = splits.get("test_clean") or splits.get("test") or {}
    per_class = test.get("per_class", [])
    weakest = [
        f"{c['class_code']} {c['label']}"
        for c in sorted(per_class, key=lambda c: c.get("recall", 0))[:2]
        if c.get("recall", 1) < 0.5
    ]

    db_metrics = {
        "split": test.get("split", "test_clean"),
        "n": test.get("n"),
        "accuracy": test.get("accuracy"),
        "macro_f1": test.get("macro_f1"),
        "top3_hit_rate": test.get("top3_hit_rate"),
        "backbone": metrics.get("backbone"),
        "domain": "WILD",
        # This caveat travels with the number so it cannot be quoted without it.
        "caveat": (
            "Measured on wild and museum-specimen imagery from iNaturalist, GBIF "
            "and ALA. Malaysian retail-counter performance is unmeasured and will "
            "be lower — different lighting, ice, cut fish, overlapping bodies."
        ),
        "weakest_classes": weakest,
        "labels_verified": False,
    }

    def jsonb(obj: dict) -> str:
        body = json.dumps(obj, indent=4, ensure_ascii=False).replace("'", "''")
        return "  '" + body + "'::jsonb"

    lines = [HEADER, "", "BEGIN;", ""]
    lines += [
        "-- Retire any previously active model. Two active versions would leave the",
        "-- resolution query ambiguous, and the adapter would keep serving whichever",
        "-- package happens to be on disk.",
        "UPDATE cv_model_version SET active = FALSE WHERE active;",
        "",
        "INSERT INTO cv_model_version (",
        "  cv_model_version_id, version_name, input_contract, metrics,",
        "  confidence_threshold, active",
        ") VALUES (",
        f"  suka_uuid5('cv_model_version:{version}'),",
        f"  '{version}',",
        jsonb(model_card["input_contract"]) + ",",
        jsonb(db_metrics) + ",",
        f"  {threshold:.4f},",
        "  TRUE",
        ")",
        "ON CONFLICT (cv_model_version_id) DO UPDATE SET",
        "  version_name         = EXCLUDED.version_name,",
        "  input_contract       = EXCLUDED.input_contract,",
        "  metrics              = EXCLUDED.metrics,",
        "  confidence_threshold = EXCLUDED.confidence_threshold,",
        "  active               = TRUE;",
        "",
        "-- =========================================================",
        "-- cv_class_mapping — frozen model class index -> canonical seafood_item",
        "-- =========================================================",
        "-- The join that makes a scanned fish the same entity as a searched one.",
        "-- The model never learns a UUID; it emits SF00x, and this table turns that",
        "-- into the key price, WWF, cooking and favourites all hang off.",
        "INSERT INTO cv_class_mapping (",
        "  cv_class_mapping_id, cv_model_version_id, seafood_item_id,",
        "  model_class_label, model_class_index",
        ")",
        "SELECT",
        f"  suka_uuid5('cv_class_mapping:{version}:' || v.code),",
        f"  suka_uuid5('cv_model_version:{version}'),",
        "  s.seafood_item_id,",
        "  v.code,",
        "  v.idx",
        "FROM (VALUES",
    ]

    width = max(len(c["label"]) for c in classes)
    for i, c in enumerate(classes):
        comma = "," if i < len(classes) - 1 else ""
        lines.append(
            f"  ({c['class_index']}, '{c['class_code']}'){comma}"
            f"   -- {c['label']:<{width}}  {c['scientific_name']}"
        )

    lines += [
        ") AS v(idx, code)",
        "JOIN seafood_item s ON s.code = v.code",
        "ON CONFLICT (cv_class_mapping_id) DO UPDATE SET",
        "  seafood_item_id   = EXCLUDED.seafood_item_id,",
        "  model_class_label = EXCLUDED.model_class_label,",
        "  model_class_index = EXCLUDED.model_class_index;",
        "",
        "-- =========================================================",
        "-- Guard rails",
        "-- =========================================================",
        "-- Each of these catches a failure that is otherwise silent: the request",
        "-- succeeds, the UUID is real, the profile renders, and the fish is wrong.",
        "DO $$",
        "DECLARE",
        "  n_active   INT;",
        "  n_mappings INT;",
        "  n_bad      INT;",
        "  n_gap      INT;",
        "  n_joined   INT;",
        "BEGIN",
        "  SELECT count(*) INTO n_active FROM cv_model_version WHERE active;",
        "  IF n_active <> 1 THEN",
        "    RAISE EXCEPTION 'expected exactly 1 active cv_model_version, found %', n_active;",
        "  END IF;",
        "",
        f"  -- The JOIN above drops silently if a code is missing, so count what",
        f"  -- actually landed rather than trusting the INSERT to have run {len(classes)} times.",
        "  SELECT count(*) INTO n_mappings",
        "    FROM cv_class_mapping m",
        "    JOIN cv_model_version v USING (cv_model_version_id)",
        "   WHERE v.active;",
        f"  IF n_mappings <> {len(classes)} THEN",
        f"    RAISE EXCEPTION 'active model has % class mappings, expected {len(classes)} — a "
        "seafood_item code in the class map does not exist', n_mappings;",
        "  END IF;",
        "",
        "  -- Model class indices must address 0..N-1 exactly, because the adapter",
        "  -- looks up the argmax of the output vector by position.",
        "  SELECT count(DISTINCT m.model_class_index) INTO n_joined",
        "    FROM cv_class_mapping m",
        "    JOIN cv_model_version v USING (cv_model_version_id)",
        f"   WHERE v.active AND m.model_class_index BETWEEN 0 AND {len(classes) - 1};",
        f"  IF n_joined <> {len(classes)} THEN",
        f"    RAISE EXCEPTION 'class indices are not a complete 0..{len(classes) - 1} set';",
        "  END IF;",
        "",
        "  -- A mapping to a species flagged not-CV-supported means the catalogue and",
        "  -- the model disagree about what the scanner can see.",
        "  SELECT count(*) INTO n_bad",
        "    FROM cv_class_mapping m",
        "    JOIN cv_model_version v USING (cv_model_version_id)",
        "    JOIN seafood_item s USING (seafood_item_id)",
        "   WHERE v.active AND NOT s.supports_cv;",
        "  IF n_bad > 0 THEN",
        "    RAISE EXCEPTION '% mapped species have supports_cv = FALSE', n_bad;",
        "  END IF;",
        "",
        "  -- Every species advertised as scannable must be in the class map, or the",
        "  -- catalogue promises a fish the model was never taught.",
        "  SELECT count(*) INTO n_gap",
        "    FROM seafood_item s",
        "   WHERE s.supports_cv",
        "     AND NOT EXISTS (",
        "       SELECT 1 FROM cv_class_mapping m",
        "       JOIN cv_model_version v USING (cv_model_version_id)",
        "       WHERE v.active AND m.seafood_item_id = s.seafood_item_id);",
        "  IF n_gap > 0 THEN",
        "    RAISE EXCEPTION '% species have supports_cv = TRUE but no class mapping', n_gap;",
        "  END IF;",
        "END $$;",
        "",
        "COMMIT;",
        "",
        "-- Verification:",
        "--   SELECT v.version_name, v.confidence_threshold, m.model_class_index,",
        "--          m.model_class_label, s.code, s.display_name_en, s.seafood_item_id",
        "--     FROM cv_model_version v",
        "--     JOIN cv_class_mapping m USING (cv_model_version_id)",
        "--     JOIN seafood_item s USING (seafood_item_id)",
        "--    WHERE v.active ORDER BY m.model_class_index;",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--handoff", type=pathlib.Path, default=DEFAULT_HANDOFF,
                    help="directory holding class_map.json and model_card.json")
    ap.add_argument("--out", type=pathlib.Path, default=DEFAULT_OUT)
    ap.add_argument("--check", action="store_true",
                    help="exit non-zero if the file on disk differs (for CI)")
    args = ap.parse_args()

    class_map = json.loads((args.handoff / "class_map.json").read_text())
    model_card = json.loads((args.handoff / "model_card.json").read_text())
    sql = build_sql(class_map, model_card)

    if args.check:
        current = args.out.read_text() if args.out.exists() else ""
        if current != sql:
            print(f"STALE: {args.out} does not match {args.handoff}.", file=sys.stderr)
            print("Run: python scripts/register_model.py", file=sys.stderr)
            return 1
        print(f"up to date: {args.out}")
        return 0

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(sql)
    n = len(class_map["classes"])
    print(f"wrote {args.out}")
    print(f"  model   {class_map['model_version']}")
    print(f"  classes {n}  ->  {n} cv_class_mapping rows")
    print("\nApplied automatically by the backend seed loader. To apply now:")
    print(f'  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f {args.out}')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
