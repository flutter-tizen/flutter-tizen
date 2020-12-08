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

Clone this repository first, and add `flutter-tizen/bin` to your **PATH** by running `export PATH=...` or editing your config file.

```sh
git clone https://github.com/flutter-tizen/flutter-tizen.git
export PATH=`pwd`/flutter-tizen/bin:$PATH
```

#### Examples

`flutter-tizen` substitutes the original [`flutter`](https://flutter.dev/docs/reference/flutter-cli) CLI command.

```sh
# Inspect the installed tooling and connected devices.
flutter-tizen doctor
flutter-tizen devices

# Set up a new project in the current directory, or add Tizen files if a Flutter project already exists.
flutter-tizen create .

# Build the project and run on a Tizen device. Use `-d [id]` to specify a device ID.
flutter-tizen run
flutter-tizen run --release
```

See [Supported commands](doc/commands.md) for all available commands and their basic usage. See `[command] -h` for more information about each command.

#### Notes

- Only the command line interface is available. We have no plan to add IDE extension support.
- To **update** the flutter-tizen tool, run `git pull` in this directory.

## Docs

#### Tizen basics

- [Setting up Tizen SDK](doc/install-tizen-sdk.md)
- [Developing for watch and TVs over Wi-Fi](doc/setup-watch-tv.md)
- Publishing watch apps on Samsung Galaxy Store (WIP)

#### App development

- [Flutter Docs](https://flutter.dev/docs)
- Development workflow (WIP)
- Debugging and inspecting Flutter apps with Dart DevTools (WIP)

#### Plugins

- [A list of Flutter plugins available for Tizen](https://github.com/flutter-tizen/plugins)
- Writing a new plugin to use platform features (WIP)

#### Advanced usage

- [Building the Flutter engine from source](https://github.com/flutter-tizen/engine/wiki/Building-the-engine)
- [Debugging the flutter-tizen tool](doc/debug-flutter-tizen.md)

## Issues

If you run into any problem, post an [issue](../../issues) in this repository to get help. If your issue is clearly not Tizen-specific (i.e it's reproducible with the regular `flutter` command), you may file an issue in https://github.com/flutter/flutter/issues.

## Contribution

This project is community-driven and we welcome all your contribution and feedbacks. Consider filing an [issue](../../issues) or [pull request](../../pulls) to make this project better.
