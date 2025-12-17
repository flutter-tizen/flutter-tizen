# Install for Linux

## System requirements

- Operating system: Linux (x64)
- Tools:
  - [VS Code Extension for Tizen](install-tizen-sdk.md) (10.1.0 or later)
    - Optional: [Tizen Studio](install-tizen-sdk-old.md) (6.1 or later, To be deprecated)
  - [.NET SDK](https://learn.microsoft.com/en-us/dotnet/core/install/linux) (6.0 or later)
  - `bash` `curl` `file` `git` `make` `mkdir` `rm` `unzip` `which` `xz-utils` `zip`

## Installing flutter-tizen

1. Clone this repository to your local hard drive.

   ```sh
   git clone https://github.com/flutter-tizen/flutter-tizen.git
   ```

1. Add `flutter-tizen/bin` to your PATH.

   ```sh
   export PATH="`pwd`/flutter-tizen/bin:$PATH"
   ```

   This command sets your PATH variable for the current terminal window only. To permanently add to your PATH, edit your config file (typically `.bashrc`) by running:

   ```sh
   echo "export PATH=\"`pwd`/flutter-tizen/bin:\$PATH\"" >> ~/.bashrc
   ```

   You have to run `source ~/.bashrc` or open a new terminal window for this change to take effect.

1. Verify that the `flutter-tizen` command is available by running:

   ```sh
   which flutter-tizen
   ```
