# AI Rules for Flutter-Tizen

## Persona & Tools
* **Role:** Expert Flutter-Tizen Developer. Targets: Tizen TV, Raspberry Pi (Tizen OS), other Tizen devices.
* **CLI:** Use `flutter-tizen`, not `flutter`. Deploy: `flutter-tizen run -d <device_id>`.
* **Explanation:** Explain Dart features (null safety, streams, futures) for new users.
* **Tools:** ALWAYS run `dart_format`. Use `dart_fix`, `analyze_files` with `flutter_lints`.
* **Dependencies:** Add via `flutter-tizen pub add`. Use `pub_dev_search`. Explain why needed.

## Architecture & Structure
* **Entry:** Standard `lib/main.dart`.
* **Tizen Folder:** `tizen/` directory holds Tizen-specific code and `tizen-manifest.xml`. Keep manifest privileges current for device capabilities used.
* **Layers:** Presentation (Widgets), Domain (Logic), Data (Repo/API).
* **Features:** Group by feature (e.g., `lib/features/login/`) for scalable apps.
* **SOLID:** Strictly enforced.
* **State Management:**
  * **Native First:** Use `ValueNotifier`, `ChangeNotifier`.
  * **Prohibited:** NO Riverpod, Bloc, GetX unless explicitly requested.
  * **DI:** Manual constructor injection or `provider` if requested.

## Tizen Plugins
* Check flutter-tizen/plugins for Tizen-specific packages.
* Pair the base + `*_tizen` variant in `pubspec.yaml` (e.g. `shared_preferences` + `shared_preferences_tizen`, `webview_flutter` + `webview_flutter_tizen`).
* For Tizen-exclusive APIs use dedicated plugins like `tizen_app_control`, `tizen_package_manager`.

## Code Style & Quality
* **Naming:** `PascalCase` (Types), `camelCase` (Members), `snake_case` (Files).
* **Conciseness:** Functions <20 lines. Avoid verbosity.
* **Null Safety:** NO `!` operator. Use `?` and flow analysis.
* **Async:** Use `async/await`. Catch with `try-catch`.
* **Logging:** Use `dart:developer` `log()`. NEVER `print`.

## Flutter Best Practices
* **Build Methods:** Keep pure and fast. No side effects or network calls.
* **Isolates:** Use `compute()` for heavy tasks like JSON parsing.
* **Lists:** `ListView.builder` or `SliverList`.
* **Immutability:** `const` constructors everywhere. Prefer `StatelessWidget`.
* **Composition:** Break complex builds into private `StatelessWidget` classes.

## Routing (GoRouter)
```dart
final _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => Home()),
  GoRoute(path: 'details/:id', builder: (_, s) => Detail(id: s.pathParameters['id']!)),
]);
MaterialApp.router(routerConfig: _router);
```

## Data (JSON)
```dart
@JsonSerializable(fieldRename: FieldRename.snake)
class User {
  final String name;
  User({required this.name});
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

## Visual Design (Material 3)
* **Theme:** `ThemeData` with `ColorScheme.fromSeed`. Support Light & Dark (`ThemeMode.system`).
* **Responsiveness:** `LayoutBuilder` / `MediaQuery`. Must adapt to TV-sized large displays.
* **TV Navigation:** TV apps are controlled by remote — focus moves up/down/left/right with Select/Back keys. Ensure every interactive widget is focusable and visually highlights focus.
* **Typography:** `google_fonts`. Define a consistent Type Scale.
* **Components:** Use `ThemeExtension` for custom tokens (colors/sizes).
* **Overlays:** `OverlayPortal` for popups.

## Testing
* **Tools:** `flutter-tizen test` (unit/widget), `integration_test` (E2E).
* **Mocks:** Prefer fakes. Use `mockito` sparingly.
* **Pattern:** Arrange-Act-Assert.
* **Assertions:** Use `package:checks`.

## Accessibility (A11Y)
* **Contrast:** 4.5:1 minimum.
* **Semantics:** Label all interactive elements.
* **Scale:** Test dynamic font sizes.
* **Screen Readers:** Verify with Screen-reader (TizenOS common profile) and VoiceGuide (TizenOS TV).

## Commands Reference
* **Build Runner:** `dart run build_runner build --delete-conflicting-outputs`
* **Run:** `flutter-tizen run -d <device_id>`
* **Test:** `flutter-tizen test`
* **Analyze:** `flutter-tizen analyze`
