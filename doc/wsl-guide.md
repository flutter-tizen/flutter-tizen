# Running flutter-tizen on WSL

You can try out [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen) on a Windows system using [WSL (Windows Subsystem for Linux)](https://docs.microsoft.com/en-us/windows/wsl/install-win10) although it's not recommended.

1. (Windows) Install [Tizen Studio](https://developer.tizen.org/development/tizen-studio/download) using the GUI installer. If you plan to test Flutter apps on Tizen emulators, also install emulator packages using _Package Manager_.

1. (Linux) Install Tizen Studio using the CLI installer. For example:

   ```sh
   # Install dependencies.
   sudo apt update
   sudo apt install wget pciutils zip libncurses5 python libpython2.7

   # Download and install Tizen Studio.
   wget http://download.tizen.org/sdk/Installer/tizen-studio_4.0/web-cli_Tizen_Studio_4.0_ubuntu-64.bin
   chmod a+x web-cli_Tizen_Studio_4.0_ubuntu-64.bin
   ./web-cli_Tizen_Studio_4.0_ubuntu-64.bin --accept-license

   # Install required packages using package-manager-cli.
   ~/tizen-studio/package-manager/package-manager-cli.bin install \
     NativeCLI NativeToolchain-Gcc-9.2 Certificate-Manager \
     WEARABLE-4.0-NativeAppDevelopment-CLI WEARABLE-5.5-NativeAppDevelopment-CLI
   ```

1. (Linux) Install flutter-tizen and add to PATH.

1. Make sure the _sdb_ server is always started by the Windows host. In other words, first run `sdb start-server` (or other sdb commands like `sdb devices`) on Windows **before** running any sdb-based commands (including `flutter-tizen`) on Linux. Otherwise, the connected devices may not be detected properly. You can stop a running server using `sdb kill-server` if it was accidentally started on Linux.

1. (Linux) Run the `doctor` command.

   ```sh
   $ flutter-tizen doctor
   [✓] Flutter (Channel unknown, 1.22.0-12.1.pre, on Linux, locale C.UTF-8)
   [✗] Android toolchain - develop for Android devices
       ✗ Unable to locate Android SDK.
   [✓] Tizen toolchain - develop for Tizen devices
   [!] Android Studio (not installed)
   [✓] Connected device (2 available)
   ```
