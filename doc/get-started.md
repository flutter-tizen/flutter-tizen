# Getting started

## Setting up the environment

1. Make sure your system and Tizen device meet the minimum requirements in [README](../README.md#system-requirements) and all the required tools are installed.

   _Note: To see which version of Tizen your device runs on (e.g. Tizen 5.5), [connect](configure-device.md) the device to your PC, run `sdb capability`, and find the `platform_version` value._

   ```
   $ sdb capability
   ...
   device_name:Tizen
   platform_version:5.5
   ...
   ```

1. Install **flutter-tizen** by referring to the [Usage](../README.md#usage) section in README. After installing, run `flutter-tizen doctor` to check if there's any issue. (You can ignore any Android-related dependency. Only `Flutter` and `Tizen toolchain` are required.)

   ```
   $ flutter-tizen doctor
   [✓] Flutter (Channel unknown, 1.22.0-12.1.pre, on Linux, locale C.UTF-8)
   [✗] Android toolchain - develop for Android devices
       ✗ Unable to locate Android SDK.
   [✓] Tizen toolchain - develop for Tizen devices
   [!] Android Studio (not installed)
   [✓] Connected device (2 available)
   ```

1. Install [**Visual Studio Code**](https://code.visualstudio.com/Download). You can also use your favorite editor.

1. Open Visual Studio Code and click the **Extensions** icon in the left menu bar. Search **Dart** in the search field and install.

   ![Dart extension](images/vs-code-dart.png)

   _Note: flutter-tizen only supports the command line interface. You can't use Flutter extension (available in VS Code) to deploy apps to a Tizen device._

1. Launch an emulator or connect your Tizen device.

   - To launch an emulator instance, use either **Emulator Manager** or the [`flutter-tizen emulators`](commands.md#emulators) command.
   - To connect a Tizen device to your PC, read the instructions in [Configuring Tizen devices for development](configure-device.md).

   You can use the `devices` command to list all attached devices.

   ```
   $ flutter-tizen devices
   2 connected devices:

   Tizen SM-R800 (mobile)           • 0000d84f00006200     • flutter-tester • Tizen 5.5
   Tizen T-samsung-5.5-x86 (mobile) • emulator-26101       • flutter-tester • Tizen 5.5 (emulator)
   ```

## Test drive

The following steps are from [Flutter Docs: Test drive](https://flutter.dev/docs/get-started/test-drive?tab=terminal) (you can just replace the `flutter` keyword with `flutter-tizen`).

### Create the app

Use the `create` command to create a new project:

```
$ flutter-tizen create myapp
$ cd myapp
```

The command creates a Flutter project directory called `myapp` that contains a simple demo app that uses [Material Components](https://material.io/guidelines). You can open the directory in Visual Studio Code to edit app source code (`lib/main.dart`).

### Run the app

Run the app with the following command:

```
$ flutter-tizen run
```

After the app build completes, you'll see the starter app on your device.

![Starter app](images/starter-app.png)

## Try hot reload

Flutter's ability to reload the code of a live running app without restarting or losing app state is called [Stateful Hot Reload](https://flutter.dev/docs/development/tools/hot-reload). After launching an app using the `run` command, you will see this help message:

```
Waiting for Tizen SM-R800 to report its views...                    11ms
Syncing files to device Tizen SM-R800...                           516ms

Flutter run key commands.
r Hot reload. 🔥🔥🔥
R Hot restart.
h Repeat this help message.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).
An Observatory debugger and profiler on Tizen SM-R800 is available at: http://127.0.0.1:34025/wG7X7TSM38k=/
```

Simply make any change to the app source (`lib/main.dart`), type `r`, and check if the change is made to the running app.

```
Performing hot reload...
Reloaded 1 of 448 libraries in 978ms.
```
