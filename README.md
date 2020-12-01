# Flutter for Tizen

An extension to the [Flutter SDK](https://github.com/flutter/flutter) for building Flutter applications for Tizen.

_Note: This project is under development and available for testing purposes only._

_Flutter and the related logo are trademarks of Google LLC. We are not endorsed by or affiliated with Google LLC._

## System requirements

- Operating system: Linux x64
  - If you're on WSL (Windows Subsystem for Linux), make sure to start the sdb server on the Windows host prior to running any sdb command from the Linux shell.
- Tools:
  - Python 3 (3.6 or later)
  - [Tizen Studio](doc/install-tizen-sdk.md) (4.0 or later)
  - [.NET Core](https://docs.microsoft.com/en-us/dotnet/core/install/linux) (3.0 or later)
- Supported devices:
  - Watch devices running Tizen 5.5 or later
  - TV devices running **Tizen 6.0** or later (older devices are not supported due to security reasons)
  - Emulators running Tizen 5.5 or later

## Usage

Clone this repository and add `flutter-tizen/bin` to your **PATH**.

```bash
export PATH=$PATH:`pwd`/flutter-tizen/bin
```

`flutter-tizen` substitutes the original `flutter` command. Not all commands or functions are supported. To see supported options and detailed information about the commands, use `-h`.

#### Examples

```bash
# Inspect the installed tooling and connected devices.
flutter-tizen doctor
flutter-tizen devices

# Add Tizen files if a Flutter project already exists in the current directory.
flutter-tizen create .

# Build a TPK (application package) without installing.
flutter-tizen build tpk

# Build the project and run on a Tizen device. Use `-d [id]` to specify a device ID.
flutter-tizen run -d tizen

# Run integration tests.
flutter-tizen drive -d tizen --driver=... --target=...
```

#### Notice

- Only the command line interface is available as of now. We don't currently support IDE (VS Code) extensions.
- To **update** the flutter-tizen tool, run `git pull` in the tool directory.

## Issues

If you run into any problem, post an [issue](../../issues) in this repository to get help. If your issue is clearly not Tizen-specific (i.e it's reproducible with the regular `flutter` command), you may file an issue in https://github.com/flutter/flutter/issues.

## Contribution

This project is community-driven and we welcome all your contribution and feedbacks. Consider filing an [issue](../../issues) or [pull request](../../pulls) to make this project better.

## Debugging flutter-tizen

To run the tool directly from source,

```bash
FLUTTER_TIZEN=$(dirname $(dirname $(which flutter-tizen)))
dart $FLUTTER_TIZEN/bin/flutter_tizen.dart --flutter-root $FLUTTER_TIZEN/flutter help
```

To force the snapshot to be re-generated, remove `bin/cache/flutter-tizen.snapshot`.

You can also debug the tool on Visual Studio Code by configuring `launch.json` as follows. You may have to change the `dart.sdkPath` value in the workspace settings if the built-in Dart SDK version is not compatible.

```json
{
  "name": "flutter-tizen",
  "request": "launch",
  "type": "dart",
  "cwd": "<path to the target application>",
  "program": "<path to flutter-tizen>/bin/flutter_tizen.dart",
  "args": ["--flutter-root", "<path to flutter-tizen>/flutter", "help"]
}
```
