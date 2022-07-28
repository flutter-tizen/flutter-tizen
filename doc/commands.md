# Supported commands

The following commands from the [Flutter CLI](https://flutter.dev/docs/reference/flutter-cli) are supported by flutter-tizen.

## Global options

- ### `-d`, `--device-id`

  Specify the target device ID. If not specified, the tool lists all connected devices.

  ```sh
  flutter-tizen -d emulator-26101 [command]
  ```

- ### `-v`, `--verbose`

  Show verbose output.

  ```sh
  flutter-tizen -v [command]
  ```

## Commands and examples

- ### `analyze`

  Analyze the current project's Dart source code. Identical to `flutter analyze`.

  ```sh
  flutter-tizen analyze
  ```

- ### `build`

  Flutter build command. See `flutter-tizen build -h` for all available subcommands.

  ```sh
  # Build a TPK for watch devices.
  flutter-tizen build tpk --device-profile wearable

  # Build a TPK and sign with a certificate profile named "foo".
  flutter-tizen build tpk --device-profile wearable --security-profile foo

  # Build a TPK for emulator.
  flutter-tizen build tpk --device-profile wearable --debug --target-arch x86
  ```

- ### `clean`

  Remove the current project's build artifacts and intermediate files.

  ```sh
  flutter-tizen clean
  ```

- ### `config`

  Configure Flutter settings. Identical to `flutter config`.

  ```sh
  # Enable Flutter for web. This takes effect globally on your system.
  flutter-tizen config --enable-web
  ```

- ### `create`

  Create a new Flutter project.

  ```sh
  # Create a new app project in "app_name" directory.
  # If a project already exists in the directory, only missing files are added.
  flutter-tizen create app_name

  # Create a new C++ app project in "app_name" directory.
  # Typically C++ apps consume less memory than C# (default) apps, but are not compatible with TV devices.
  flutter-tizen create --tizen-language cpp app_name

  # Create a new plugin project in "plugin_name" directory.
  flutter-tizen create --platforms tizen --template plugin plugin_name

  # Create a new C# plugin project in "plugin_name" directory.
  flutter-tizen create --platforms tizen --template plugin --tizen-language csharp plugin_name

  # Create a new C++ module project in "module_name" directory.
  flutter-tizen create --template module --tizen-language cpp module_name
  ```

- ### `devices`

  List all connected devices.

  ```sh
  flutter-tizen devices
  ```

- ### `doctor`

  Show information about the installed tooling.

  ```sh
  flutter-tizen doctor -v
  ```

- ### `drive`

  Run integration tests for the project on an attached device. For detailed usage, see [`integration_test`](https://github.com/flutter/flutter/tree/master/packages/integration_test).

  ```sh
  # Launch "integration_test/foo_test.dart" on a Tizen device.
  flutter-tizen drive --driver=test_driver/integration_test.dart --target=integration_test/foo_test.dart
  ```

- ### `emulators`

  List, launch, and create Tizen emulators.

  ```sh
  # List all emulator instances.
  flutter-tizen emulators

  # Launch a TV 6.0 emulator.
  flutter-tizen emulators --launch T-samsung-6.0-x86
  ```

- ### `format`

  Format Dart files. Identical to `flutter format`.

  ```sh
  flutter-tizen format foo.dart
  ```

- ### `gen-l10n`

  Generate [localizations](https://flutter.dev/docs/development/accessibility-and-localization/internationalization) for the Flutter project. Identical to `flutter gen-l10n`.

  ```sh
  flutter-tizen gen-l10n
  ```

- ### `install`

  Install a Flutter app on an attached device.

  ```sh
  # Install "build/tizen/tpk/*.tpk" on a Tizen device.
  flutter-tizen install

  # Uninstall if already installed.
  flutter-tizen install --uninstall-only
  ```

- ### `precache`

  Populate the Flutter tool's cache of binary artifacts.

  ```sh
  # Download artifacts required for Tizen app development.
  flutter-tizen precache --tizen
  ```

- ### `pub`

  Commands for managing Flutter packages. Identical to `flutter pub`.

  ```sh
  # Get packages for the current project.
  flutter-tizen pub get
  ```

- ### `run`

  Build the current project and run on a connected device. For more information on each build mode, see [Flutter Docs: Flutter's build modes](https://flutter.dev/docs/testing/build-modes).

  ```sh
  # Build and run in debug mode.
  flutter-tizen run

  # Build and run in release mode.
  flutter-tizen run --release

  # Build and run in profile mode.
  flutter-tizen run --profile

  # Show verbose logs from the Flutter engine (debug mode only).
  flutter-tizen run --verbose-system-logs

  # Install "foo.tpk" and run without building the project.
  flutter-tizen run --use-application-binary foo.tpk

  # Run and wait for a debugger to attach.
  flutter-tizen run --start-paused
  ```

- ### `screenshot`

  Take a screenshot from a connected device.

  ```sh
  flutter-tizen screenshot --type rasterizer --observatory-uri http://127.0.0.1:43000/Swm0bjIe0ks=
  ```

  You have to specify both `--type` and `--observatory-uri` values because the default (`device`) screenshot type is not supported by Tizen devices. The observatory URI value can be found in the device log output (`flutter-tizen run` or `flutter-tizen logs`) after you start an app in debug or profile mode.

  If you're using a watch device, you can also take a screenshot by swiping the screen from left to right while pressing the Home button.

- ### `symbolize`

  Symbolize a stack trace from a Flutter app which has been built with the `--split-debug-info` option.

  ```sh
  flutter-tizen symbolize --debug-info app.android-arm.symbols --input stack_trace.err
  ```

- ### `test`

  Run Flutter unit tests or integration tests for the current project. See [Flutter Docs: Testing Flutter apps](https://flutter.dev/docs/testing) for details. Also check out the [`drive`](#drive) command if you want to run an integration test with a custom driver script.

  ```sh
  # Run all tests in "test" directory.
  flutter-tizen test

  # Run all integration tests in "integration_test" directory.
  flutter-tizen test integration_test
  ```

## Not supported

The following commands from the Flutter CLI are not supported by flutter-tizen.

- `assemble`
- `attach`
- `bash-completion`
- `channel`
- `custom-devices`
- `downgrade`
- `logs`
- `upgrade`
