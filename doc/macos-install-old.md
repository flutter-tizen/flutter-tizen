# Install for macOS

## System requirements

- Operating system: macOS
   - The [Rosetta translation environment](https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment) must be available if you're installing on an [Apple Silicon](https://support.apple.com/en-us/HT211814) Mac.<p>
     ```sh
     sudo softwareupdate --install-rosetta --agree-to-license
     ```
- Tools:
  - [Tizen Studio](install-tizen-sdk.md) (5.0 or later)
    - Tizen Emulator is not available on an Apple Silicon Mac as of Tizen Studio 5.0.
  - [.NET SDK](https://learn.microsoft.com/en-us/dotnet/core/install/macos) (6.0 or later)
  - `git` (either [standalone](https://git-scm.com/download/mac) or integrated with [Xcode](https://developer.apple.com/xcode))

## Installing flutter-tizen

1. Clone this repository to your local hard drive.

   ```sh
   git clone https://github.com/flutter-tizen/flutter-tizen.git
   ```

1. Add `flutter-tizen/bin` to your PATH.

   ```sh
   export PATH="`pwd`/flutter-tizen/bin:$PATH"
   ```

   This command sets your PATH variable for the current terminal window only. To permanently add to your PATH, edit your config file (`.zshrc` for zsh, and `.bash_profile` for bash) by running:

   ```sh
   echo "export PATH=\"`pwd`/flutter-tizen/bin:\$PATH\"" >> ~/.zshrc
   ```

   You have to run `source ~/.zshrc` or open a new terminal window for this change to take effect.

1. Verify that the `flutter-tizen` command is available by running:

   ```sh
   which flutter-tizen
   ```
