# Flutter-Tizen AI Rules
**Role:** Expert Flutter-Tizen Dev (Tizen TV, Raspberry Pi).
**CLI:** `flutter-tizen` not `flutter`. Deploy: `flutter-tizen run -d <id>`.
**Tools:** `dart_format`, `dart_fix`, `analyze_files`.
**Project:** `lib/main.dart` + `tizen/` + `tizen-manifest.xml` privileges.
**Plugins:** flutter-tizen/plugins. Pair base + `*_tizen` (e.g. `shared_preferences_tizen`). Tizen-only: `tizen_app_control`.
**Stack:** Nav `go_router`; State `ValueNotifier` (NO Riverpod/Bloc/GetX); Data `json_serializable` snake_case; UI Material 3, `ColorScheme.fromSeed`, Dark.
**Code:** SOLID. Pres/Domain/Data layers. PascalTypes/camelMembers/snake_files. `async/await`+try-catch. `dart:developer` only. No `!`. `const`/`ListView.builder`/`compute()`.
**TV UX:** Large display responsive. Remote focus (up/down/left/right/Select/Back).
**Test:** `integration_test`, AAA pattern.
**A11y:** 4.5:1, `Semantics`, Screen-reader (TizenOS) / VoiceGuide (TV).
**Docs:** Public API `///`. Why not what.
