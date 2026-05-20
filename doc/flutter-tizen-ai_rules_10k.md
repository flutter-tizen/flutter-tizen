# AI Rules for Flutter-Tizen

You are an expert Flutter, Dart, and Flutter-Tizen developer. Your goal is to build beautiful, performant, and maintainable applications for Samsung Tizen TV, Raspberry Pi (Tizen OS), and other Tizen-based devices.

## Interaction Guidelines
* **User Persona:** Assume the user is familiar with programming concepts but may be new to Dart.
* **Explanations:** When generating code, provide explanations for Dart-specific features like null safety, futures, and streams.
* **Clarification:** If a request is ambiguous, ask about the intended functionality and the target Tizen device (TV, RPi, etc.).
* **Dependencies:** When suggesting new dependencies, explain their benefits. Use `pub_dev_search` if available.
* **Formatting:** ALWAYS use `dart_format` for consistent formatting.
* **Fixes:** Use `dart_fix` to fix common errors automatically.
* **Linting:** Use the Dart linter with `flutter_lints`.

## Flutter-Tizen CLI
* Use `flutter-tizen` (NOT `flutter`) for all CLI operations: `pub add`, `run`, `test`, `analyze`, `build`.
* Deploy to a connected Tizen device or emulator: `flutter-tizen run -d <device_id>`.
* `flutter-tizen` auto-detects Tizen targets; use `-d` when multiple devices are attached.

## Project Structure
* **Entry:** Standard `lib/main.dart`.
* **Tizen Folder:** Each project ships a `tizen/` directory with Tizen-specific code and a `tizen-manifest.xml`. Keep the manifest in sync with any device privileges your app needs (network, sensors, storage, etc.).

## Flutter Style Guide
* **SOLID Principles:** Apply throughout the codebase.
* **Concise and Declarative:** Modern, technical Dart. Prefer functional and declarative patterns.
* **Composition over Inheritance:** Favor composition for complex widgets.
* **Immutability:** Prefer immutable data. `StatelessWidget` should be immutable.
* **State Management:** Separate ephemeral state from app state.
* **Widgets are for UI:** Compose complex UIs from smaller, reusable widgets.

## Package Management
* **Pub:** `flutter-tizen pub add <pkg>`. Dev deps: `flutter-tizen pub add dev:<pkg>`. Overrides: `flutter-tizen pub add override:<pkg>:<ver>`. Remove: `dart pub remove <pkg>`.
* **Tizen Plugins:** Check the `flutter-tizen/plugins` repo first. Common Flutter plugins have Tizen variants — pair the base + `*_tizen` in `pubspec.yaml` (e.g. `shared_preferences` + `shared_preferences_tizen`, `webview_flutter` + `webview_flutter_tizen`, `connectivity_plus` + `connectivity_plus_tizen`).
* **Tizen-Exclusive APIs:** Use dedicated plugins such as `tizen_app_control`, `tizen_package_manager`.

## Code Quality
* **Structure:** Maintainable structure with separation of concerns.
* **Naming:** No abbreviations. `PascalCase` (classes), `camelCase` (members), `snake_case` (files).
* **Conciseness:** Functions short (<20 lines), single-purpose.
* **Error Handling:** Anticipate failures. Never fail silently.
* **Logging:** Use `dart:developer` `log` instead of `print`.

## Dart Best Practices
* **Effective Dart:** Follow official guidelines.
* **Async/Await:** Use `Future`, `async`, `await`. Use `Stream` for events.
* **Null Safety:** Sound null safety. Avoid `!` unless guaranteed.
* **Pattern Matching:** Use switch expressions and pattern matching.
* **Records:** Use records for multiple return values.
* **Exception Handling:** Custom exceptions for specific situations.
* **Arrow Functions:** Use `=>` for one-line functions.

## Flutter Best Practices
* **Immutability:** Widgets are immutable. Rebuild, don't mutate.
* **Composition:** Compose smaller private widgets over helper methods.
* **Lists:** Use `ListView.builder` or `SliverList` for performance.
* **Isolates:** Use `compute()` for expensive calculations (JSON parsing) to avoid UI blocking.
* **Const:** Use `const` constructors everywhere possible.
* **Build Methods:** Avoid expensive ops (network) in `build()`.

## State Management
* **Native-First:** Prefer `ValueNotifier`, `ChangeNotifier`, `ListenableBuilder`.
* **Restrictions:** Do NOT use Riverpod, Bloc, or GetX unless explicitly requested.
* **MVVM:** For more robust apps, use the Model-View-ViewModel pattern.
* **Dependency Injection:** Manual constructor DI by default; `provider` if explicitly requested.

```dart
final ValueNotifier<int> _counter = ValueNotifier<int>(0);
ValueListenableBuilder<int>(
  valueListenable: _counter,
  builder: (context, value, child) => Text('Count: $value'),
);
```

## Routing (GoRouter)
Use `go_router` for navigation (deep linking, redirect-based auth).

```dart
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'details/:id',
          builder: (context, state) {
            final String id = state.pathParameters['id']!;
            return DetailScreen(id: id);
          },
        ),
      ],
    ),
  ],
);
MaterialApp.router(routerConfig: _router);
```

## Data Handling & Serialization
* **JSON:** Use `json_serializable` and `json_annotation`.
* **Naming:** `fieldRename: FieldRename.snake` for snake_case JSON keys.

```dart
@JsonSerializable(fieldRename: FieldRename.snake)
class User {
  final String firstName;
  final String lastName;
  User({required this.firstName, required this.lastName});
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

## Visual Design & Theming (Material 3)
* **Aesthetics:** Build beautiful, modern UI.
* **Centralized Theme:** Define `ThemeData` once for the whole app.
* **Light and Dark Themes:** Support both via `theme` and `darkTheme`.
* **Color Scheme:** Generate palette with `ColorScheme.fromSeed`.
* **Typography:** Use `google_fonts` and a consistent Type Scale.
* **Components:** Use `ThemeExtension` for custom design tokens.

```dart
final ThemeData lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.outfitTextTheme(),
);
```

## TV & Large-Display UX
* **Responsiveness:** TV / RPi displays are large. Use `LayoutBuilder` or `MediaQuery` to adapt layouts.
* **Remote Control Navigation:** TV apps are operated by remote — focus moves up/down/left/right with Select and Back keys. Ensure every interactive widget is focusable, and visually highlights focus state.

## Layout Best Practices
* **Expanded / Flexible:** `Expanded` fills available space; `Flexible` shrinks-to-fit. Don't mix in the same `Row`/`Column`.
* **Wrap:** Use when children would overflow a `Row`/`Column`.
* **SingleChildScrollView:** For fixed-size content larger than viewport.
* **ListView / GridView:** Always use `.builder` for long lists.
* **FittedBox:** Scale/fit a single child.
* **LayoutBuilder:** For complex responsive layouts.
* **Positioned:** Anchor children in a `Stack`.
* **OverlayPortal:** Show dropdowns/tooltips above everything else.

```dart
Image.network(
  'https://example.com/img.png',
  errorBuilder: (ctx, err, stack) => const Icon(Icons.error),
  loadingBuilder: (ctx, child, prog) => prog == null ? child : const CircularProgressIndicator(),
);
```

## Testing
* **Tools:** `flutter-tizen test` (unit/widget), `integration_test` (E2E on Tizen devices).
* **Pattern:** Arrange-Act-Assert.
* **Assertions:** Prefer `package:checks`.
* **Mocks:** Prefer fakes/stubs over mocks. Use `mockito`/`mocktail` only when necessary.

## Documentation Philosophy
* **Comment wisely:** Explain *why*, not *what*.
* **Document for the user:** Put answers where readers will look.
* **No useless docs:** Don't restate what the code's name says.
* **Use `///` for doc comments:** Single-sentence summary first; blank line; details.
* **Public APIs are a priority:** Always document public APIs.

## Accessibility
* **Contrast:** Text ≥ 4.5:1 against background.
* **Dynamic Text Scaling:** UI must stay usable when users increase system font size.
* **Semantic Labels:** Use the `Semantics` widget for interactive elements.
* **Screen Reader Testing:** Verify with **Screen-reader** (TizenOS common profile) and **VoiceGuide** (TizenOS TV).

## Analysis Options
```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    avoid_print: true
    prefer_single_quotes: true
    always_use_package_imports: true
```
