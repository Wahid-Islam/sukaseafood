# Frontend — SukaSeafood Mobile

Flutter client for **iOS and Android**. Consumes the backend HTTP API only — no direct database access.

## Responsibility

- Home / quick actions
- Search (Epic 1)
- Camera identify + confirmation (Epic 1, mock CV)
- Seafood profile: Understand / Price / Cook tabs (Epics 2–4)
- Cooking intent browser (Epic 4)
- Favourites + profile shells (supporting I1)

## Stack

- Flutter 3.44 / Dart 3.12
- go_router
- http
- fl_chart
- image_picker
- google_fonts

## Layout

```
frontend/
├── lib/
│   ├── core/           # theme, router, constants
│   ├── data/           # API client + models
│   ├── features/       # feature modules (UI)
│   └── shared/         # shared widgets
├── android/
├── ios/
├── test/
├── pubspec.yaml
└── README.md
```

## Run

```powershell
cd frontend
flutter pub get
flutter emulators --launch Pixel_8_API_36
flutter run
```

### API base URL

Default (Android emulator → host machine):

```
http://10.0.2.2:8000/api/v1
```

Override:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

iOS Simulator typically uses `http://127.0.0.1:8000/api/v1` (macOS + Xcode required).

## Quality

```powershell
dart analyze lib
flutter test
```
