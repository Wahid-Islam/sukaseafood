# Frontend — SukaSeafood

Flutter UI matched to `PotentialScreenrendersI1.pdf`.

## Screens

| Route | Screen |
| --- | --- |
| `/home` | Home (featured fish, pulse, cooking CTA, favourites) |
| `/explore` | Search / discover |
| `/scan` | Camera identify (mock predictions for now) |
| `/favorites` | Saved seafood |
| `/profile` | Guest profile shell |
| `/seafood/:id` | Sustainability detail |
| `/price/:id` | Price (observed + outlook) |
| `/cooking/:id` | Cooking intent |

## Data

Uses `lib/data/mock/mock_catalog.dart` — no live backend required for UI demos.

Next: PocketBase Dart client (see `docs/architecture/lean-stack.md`).

## Run

```powershell
cd frontend
flutter pub get
flutter run -d emulator-5554
```
