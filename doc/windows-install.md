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

   Note: The target path must not contain spaces.

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
