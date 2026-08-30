# Field guide — collecting the SukaSeafood I1 training images

This is the task that decides whether Iteration 1 has a working scanner. The
code is finished and tested; it is waiting on photographs.

Fish-Vista gave us 61 images across all five species, and every one is a
preserved museum specimen on a measuring board. The app's users will photograph
a wet fish on a wet slab. Those are different problems. The images below are the
ones that matter.

---

## What to photograph

The five frozen species, and nothing else:

| Code | Name | Scientific name | What to look for |
|---|---|---|---|
| SF001 | Kembung / Pelaling | *Rastrelliger kanagurta* | Slender silver body, dark spot line along the flank, forked tail |
| SF002 | Bawal Hitam | *Parastromateus niger* | Deep, flat, disc-shaped silver-grey body, tiny mouth |
| SF003 | Ikan Merah | *Lutjanus sebae* | Red body; juveniles show broad dark bands |
| SF004 | Tilapia | *Oreochromis niloticus* | Deep grey-olive body, vertical bars on the tail |
| SF005 | Kerapu Bintik | *Epinephelus coioides* | Heavy body, wide mouth, brown spotting |

**One whole fish, mostly visible.** Fillets, steaks, heads and cooked fish are
outside Iteration 1 — a photo of a fillet is not a training image for us, though
a few make useful `test_invalid` examples.

---

## How many

Per species, before training can start:

| | Count | Notes |
|---|---:|---|
| Training | **150–300** | The floor is 150. Below that, the model is unpredictable |
| Validation | 30–50 | Split automatically from what you collect |
| Clean test | 20–30 | Split automatically |
| **Dirty retail test** | **30–50** | Collected separately — see below |

Plus, once, across all classes: **40–60 invalid inputs** — fillets, prawns,
chicken, other fish species, a blurry photo, a photo of the floor. These prove
the app says "not sure" instead of confidently naming a fish.

Run `python scripts/check_dataset.py --manifest data/manifest.csv --root data/images`
after every batch. It prints exactly what is still short.

---

## The rule that matters most

**The dirty retail test set is collected on a different day, at a different
market, ideally by a different person — and it is never trained on.**

That set is where the number in the final report comes from. If it overlaps with
training data, every accuracy figure the team reports is fiction, and the demo
will be the moment everyone finds out. `check_dataset.py` warns when the two
share a collection source, but it cannot detect a photo taken three metres away
from a training photo.

---

## How to shoot

**Vary everything.** A model trained on 200 photos that all look alike has
learned one photo. Across each species, deliberately vary:

- **Angle** — side-on, three-quarter, slightly above. Side-on is the most useful
  view because body depth is what separates Kembung from Bawal Hitam.
- **Lighting** — fluorescent market tube, daylight at a roadside stall,
  supermarket chill-counter LED. These have very different colour casts, and
  colour is a real signal for Ikan Merah.
- **Background** — ice, steel slab, plastic tray, polystyrene box, banana leaf.
- **Condition** — wet, dry, whole tray, single fish, fish with a price tag,
  a hand or tongs in frame. Hands in frame are good: users will have them.
- **Phone** — use every phone the team owns. Different sensors and different
  default processing.
- **Distance** — fill the frame, and also step back so the fish is one of
  several on the tray.

**What not to do:**

- Don't take 20 photos of the same fish from the same spot. Move, or move on.
  If you do shoot burst variants of one fish, that is fine — but they must all
  carry the same `original_group_id` so they stay in one split.
- Don't photograph a species you are not sure about. See below.
- Don't crop or edit before ingesting. Ingest the original; the pipeline handles
  resizing and augmentation.

---

## Labelling — the part that quietly ruins models

Market names are not species names.

- "Kembung" is used for more than one *Rastrelliger*.
- "Ikan Merah" is applied to several snappers beyond *Lutjanus sebae*.
- Farmed tilapia in Malaysia is often a *niloticus* hybrid.

If you are not confident, **ask the vendor, photograph it anyway, and flag it**
rather than guessing. A wrong label is worse than a missing image: it teaches the
model to be confidently wrong, and confidence is exactly what the LOW_CONFIDENCE
threshold has to be able to trust.

Every uncertain image gets a second reviewer before it enters training (09 s.3).

---

## Permission and licence

- Ask before photographing a vendor's stock. Most will say yes; a few will not.
- Record who took each photo — `--attribution` on ingest.
- Team photos are `own-work, team permission granted`.
- Vendor photos need recorded permission; note it in the manifest.
- Web images must be CC BY / CC BY-SA / CC0 with the URL captured. Anything
  unclear gets `licence_usable=REVIEW` and stays out of training until resolved.

**Never** use a photo a user uploaded through the app. That is prohibited by
08 s.11 and there is no exception for "just a few".

---

## Ingesting a batch

Sort into one folder per class code, then:

```bash
# a normal training batch
python scripts/ingest_folder.py \
    --incoming incoming --out-dir data/images --manifest data/manifest.csv \
    --domain RETAIL \
    --source "Pasar Borong Selayang 2026-08-30" \
    --attribution "Your Name"

# a dirty retail batch — pinned out of training permanently
python scripts/ingest_folder.py \
    --incoming incoming_dirty --out-dir data/images --manifest data/manifest.csv \
    --domain RETAIL --split test_dirty \
    --source "Pasar Chow Kit 2026-09-06" \
    --attribution "Someone Else"

# invalid / unsupported inputs
python scripts/ingest_folder.py \
    --incoming incoming_invalid --out-dir data/images --manifest data/manifest.csv \
    --domain INVALID --split test_invalid \
    --source "mixed, 2026-09-06" --attribution "Your Name"

# then check what is still missing
python scripts/check_dataset.py --manifest data/manifest.csv --root data/images
```

Duplicate photos are detected by content hash and skipped, so re-running an
ingest is safe.

---

## When you are done

`check_dataset.py` exits cleanly. That is Gate 1. Training is then roughly
twenty minutes of CPU, and the rest of the pipeline is already built and tested.
