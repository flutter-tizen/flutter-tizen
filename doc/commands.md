# Supported commands

Not all commands in the [`flutter`](https://flutter.dev/docs/reference/flutter-cli) CLI are supported by `flutter-tizen`.

## Global options

- ### `-d`, `--device-id`

  Specify the target device ID. The tool finds a connected device automatically if not specified.

  ```sh
  flutter-tizen [command] -d emulator-26101
  ```

- ### `-v`, `--verbose`

  Show verbose output.

  ```sh
  flutter-tizen [command] -v
  ```

## Commands and examples

- ### `analyze`

  Analyze the current project's Dart source code. Identical to `flutter analyze`.

  ```sh
  flutter-tizen analyze
  ```

- ### `attach`

  Attach to a Flutter app running on a Tizen device.

  ```sh
  flutter-tizen attach
  ```

- ### `build`

  Flutter build command. See `flutter-tizen build -h` for subcommands.

  ```sh
  # Build a TPK without installing on a device.
  flutter-tizen build tpk

  # Build for an emulator.
  flutter-tizen build tpk --debug --target-arch x86
  ```

- ### `clean`

  Remove the current project's build artifacts and intermediate files.

  ```sh
  flutter-tizen clean
  ```

- ### `config`

  Configure Flutter settings. Identical to `flutter config`.

  ```sh
  # Enable Flutte for web. This takes effect globally.
  flutter-tizen config --enable-web
  ```

- ### `create`

  Create a new project.

  ```sh
  # Create a new app project in the current directory.
  # If a project already exists in the current directory, only missing files are added.
  flutter-tizen create .

  # The Tizen embedding APIs are not yet stable.
  # Delete and re-create the `tizen` directory as often as you can.
  rm -r tizen/
  flutter-tizen create .

  # Create a new plugin project in `foobar_tizen` directory.
  flutter-tizen create --template plugin --org com.example foobar_tizen
  ```

- ### `devices`

  List all connected devices.

  ```sh
  flutter-tizen devices
  ```

- ### `doctor`

  Show information about the installed Tizen tooling.

  ```sh
  flutter-tizen doctor
  ```

- ### `drive`

  Run Flutter Driver tests. For details, see [`integration_test`](https://github.com/flutter/plugins/tree/master/packages/integration_test) (plugin).

  ```sh
  # Launch `foo_test.dart` on a Tizen device.
  flutter-tizen drive --driver=test_driver/integration_test.dart --target=integration_test/foo_test.dart
  ```

- ### `emulators`

  List and launch Tizen emulators.

  ```sh
  # List all emulator instances.
  flutter-tizen emulators

  # Launch a TV 5.5 emulator.
  flutter-tizen emulators --launch T-samsung-5.5-x86
  ```

- ### `format`

  Format Dart files. Identical to `flutter format`.

  ```sh
  flutter-tizen format foo.dart
  ```

- ### `install`

  Install TPK on a Tizen device.

  ```sh
  # Install `build/tizen/*.tpk` on a Tizen device.
  flutter-tizen install

  # Uninstall if already installed.
  flutter-tizen install --uninstall-only
  ```

- ### `logs`

  Show the device log output associated with running Flutter apps.

  ```sh
  flutter-tizen logs
  ```

- ### `pub`

  Commands for managing Flutter packages. Identical to `flutter pub`.

  ```sh
  # Get packages for the current project.
  flutter-tizen pub get
  ```

- ### `run`

  Build the current project and run on a Tizen device.

  ```sh
  # Build and run in debug mode.
  flutter-tizen run

  # Build and run in release mode.
  # Full performance, but no debugging (hot-reload) support.
  flutter-tizen run --release

  # Specify the device ID to run on.
  flutter-tizen run -d emulator-26101
  ```
