# Install for Windows

## System requirements

- Operating system: Windows 7 SP1 or later (64-bit)
- Tools:
  - Python 3 (3.6 or later)
    - If you're on Windows 10, you can run `python3` in a console window to get Python from Microsoft Store.
  - [Tizen Studio](install-tizen-sdk.md) (4.0 or later)
  - [.NET SDK](https://docs.microsoft.com/en-us/dotnet/core/install/windows) (3.0 or later)
  - [Git for Windows](https://git-scm.com/download/win) 2.x (enable the **Use Git from the Windows Command Prompt** option)

## Installing flutter-tizen

1. Clone this repository to your local hard drive.

   ```powershell
   git clone https://github.com/flutter-tizen/flutter-tizen.git
   ```

1. Add `flutter-tizen\bin` to your PATH.

   - From the Start search bar, enter "env" and select **Edit environment variables for your account**.
   - Under **User variables** check if there is an entry called **Path**:
     - If the entry exists, click **Edit...** and add a new entry with the full path to `flutter-tizen\bin`.
     - If the entry doesn't exist, create a new user variable named **Path** with the full path to `flutter-tizen\bin` as its value.

   You have to close and reopen any existing console windows for this change to take effect.

1. Verify that the `fluter-tizen` command is available by running:

   ```powershell
   where.exe flutter-tizen
   ```

## Running flutter-tizen on WSL (Windows Subsystem for Linux)

If you experience any performance issue, you can alternatively run flutter-tizen on Windows Subsystem for Linux.

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

1. (Linux) Install [flutter-tizen](linux-install.md#installing-flutter-tizen) and add to your PATH.

1. (Windows) Restart the **sdb** server by running `sdb kill-server` and `sdb start-server`.

1. (Linux) Run the `doctor` command.

   ```
   $ flutter-tizen doctor
   [✓] Flutter (Channel unknown, 1.22.0-12.1.pre, on Linux, locale C.UTF-8)
   [✗] Android toolchain - develop for Android devices
       ✗ Unable to locate Android SDK.
   [✓] Tizen toolchain - develop for Tizen devices
   [!] Android Studio (not installed)
   [✓] Connected device (2 available)
   ```
