# flutter_tizen

[![pub package](https://img.shields.io/pub/v/flutter_tizen.svg)](https://pub.dev/packages/flutter_tizen)

Tizen utilities for Dart and Flutter. Provides system information and profile detection for Tizen applications.

_⚠️Caution: This package is experimental and the API may change in the future._

## Usage

To use this package, add `flutter_tizen` as a dependency in your `pubspec.yaml` file.

```yaml
dependencies:
  flutter_tizen: ^0.2.6
```

### Checking Tizen environment

Use the `isTizen` getter to determine if your application is running on a Tizen device.

```dart
import 'package:flutter_tizen/flutter_tizen.dart';

if (isTizen) {
  // Running on Tizen device.
} else {
  // Not running on Tizen.
}
```

### Detecting Tizen profiles

Tizen supports different device profiles. Use the profile getters to determine the current runtime environment.

```dart
import 'package:flutter_tizen/flutter_tizen.dart';

if (isTvProfile) {
  // Running on Tizen TV profile.
} else if (isTizenProfile) {
  // Running on Tizen(Common) profile.
} else {
  // Running on a different profile or platform.
}
```

### Getting API version

Get the Tizen API version of the currently running TizenOS.

```dart
import 'package:flutter_tizen/flutter_tizen.dart';

String version = apiVersion;
if (version != 'none') {
  // Tizen API Version: $version.
}
```
