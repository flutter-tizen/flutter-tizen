# Install for macOS

## System requirements

- Operating system: macOS (Intel 64-bit)
- Tools:
  - [Python 3](https://www.python.org/downloads/mac-osx) (3.6 or later)
  - [Tizen Studio](install-tizen-sdk.md) (4.0 or later)
  - [.NET SDK](https://docs.microsoft.com/en-us/dotnet/core/install/macos) (3.0 or later)

## Installing flutter-tizen

1. Clone this repository to your local hard drive.

   ```sh
   git clone https://github.com/flutter-tizen/flutter-tizen.git
   ```

1. Add `flutter-tizen/bin` to your PATH.

   ```sh
   export PATH=`pwd`/flutter-tizen/bin:$PATH
   ```

   This command sets your PATH variable for the current terminal window only. To permanently add to your PATH, edit your config file (`.bash_profile` or `.bashrc` if using Bash, and `.zshrc` if using Z shell) by running:

   ```sh
   echo "export PATH=`pwd`/flutter-tizen/bin:\$PATH" >> ~/.bash_profile
   ```

   You have to run `source ~/.bash_profile` or open a new terminal window for this change to take effect.

1. Verify that the `fluter-tizen` command is available by running:

   ```sh
   which flutter-tizen
   ```
