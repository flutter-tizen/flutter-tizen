<p align="center"><img src="doc/images/flutter-tizen.png" width="500"/></p>

# Flutter for Tizen

[![Test](https://github.com/flutter-tizen/flutter-tizen/workflows/Test/badge.svg)](https://github.com/flutter-tizen/flutter-tizen/actions)

An extension to the [Flutter SDK](https://github.com/flutter/flutter) for building Flutter applications for Tizen devices.

_Flutter and the related logo are trademarks of Google LLC. This project is sponsored and maintained by Samsung Research._

## Supported devices

- **Smart TV**: [Tizen 6.0 (2021) or later](https://developer.samsung.com/smarttv/develop/specifications/tv-model-groups.html)
- **IoT (RPi 3/4)**: Tizen 6.0 or later
- **Galaxy Watch**: Not supported (use [3.16.2](https://github.com/flutter-tizen/flutter-tizen/tags) or older releases)

## Installation

- [Linux (x64)](doc/linux-install.md)
- [Windows (x64)](doc/windows-install.md)
- [macOS (x64)](doc/macos-install.md)

## Usage

`flutter-tizen` substitutes the original [`flutter`](https://docs.flutter.dev/reference/flutter-cli) CLI command. Only the command line interface is supported.

```sh
# Inspect the installed tooling and list all connected devices.
flutter-tizen doctor -v
flutter-tizen devices

# Set up a new app project, or add Tizen files if the project already exists.
flutter-tizen create myapp
cd myapp

# Build the project and run on a Tizen device (either in debug or release mode).
flutter-tizen run
flutter-tizen run --release
```

- See [Supported commands](doc/commands.md) for all available commands and their basic usage. See `[command] -h` for more information on each command.
- See [Getting started](doc/get-started.md) to create your first app and try **hot reload**.
- To **update** the flutter-tizen tool, run `git pull` in this directory.

## Docs

#### Tizen basics

- [Setting up Tizen SDK](doc/install-tizen-sdk.md)
- [Configuring Tizen devices for development](doc/configure-device.md)

#### App development

- [Getting started](doc/get-started.md)
- [Debugging apps](doc/debug-app.md)
- [Flutter Docs](https://docs.flutter.dev)

#### Platform integration

- [Flutter plugins for Tizen](https://github.com/flutter-tizen/plugins)
- [Dart bindings for Tizen APIs](https://github.com/flutter-tizen/tizen_interop)

#### Miscellaneous

- [Publishing apps on Samsung Galaxy Store and TV Seller Office](doc/publish-app.md)
- [Wiki](https://github.com/flutter-tizen/flutter-tizen/wiki)
- [AI Rules](doc/ai_rules.md)

## Issues

If you run into any problem, post an [issue](../../issues) in this repository to get help. If your issue is clearly not Tizen-specific (i.e. it's reproducible with the regular `flutter` command), you may file an issue in https://github.com/flutter/flutter/issues.

## Contribution

This project is community-driven and we welcome all your contributions and feedback. Consider filing an [issue](../../issues) or [pull request](../../pulls) to make this project better.
