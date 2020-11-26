# Getting Tizen Studio

Follow the below instructions to install and configure Tizen SDK on your host machine.

## Install Tizen Studio

Download and install the latest release of Tizen Studio from the below URL. It is recommended to use the GUI installer although you can still build Flutter apps with CLI only.

- [Download Tizen Studio](https://developer.tizen.org/development/tizen-studio/download)
- [Installing Tizen Studio - Tizen Docs](https://docs.tizen.org/application/tizen-studio/setup/install-sdk)

If done, make sure the tools path (usually `~/tizen-studio/tools`) is in your PATH. If it's not, add it by using `export PATH=...` or editing your `.bashrc` file.

```bash
echo $PATH
export PATH=$HOME/tizen-studio/tools:$PATH
```

_Note: You can also specify the Tizen Studio installation path with `TIZEN_SDK` environment variable._

## Install required packages

You need to also install required packages using _Tizen Package Manager (GUI)_ or _package-manager-cli_.

![Tizen Package Manager](images/tizen-package-manager.png)

- A minimal set of packages required by the flutter-tizen tool includes:
  - _[Tizen SDK tools] - [Native CLI]_
  - _[Tizen SDK tools] - [Native toolchain] - [Gcc 9.2 toolchain]_
  - _[Tizen SDK tools] - [Baseline SDK] - [Certificate Manager]_
  - _[5.5 Wearable] - [Advanced] - [Native app. development (CLI)]_
  - _[Extension SDK] - [Samsung Certificate Extension]_
- Optionally, you may also install these packages:
  - _[5.5 Wearable] - [Emulator]_
  - _[Extension SDK] - [TV Extensions-5.5] - [Emulator]_

## Create a Tizen certificate

In order to sign your application package, you have to create your own certificate. Use Certificate Manager (GUI), or the `tizen certificate/security-profiles` command ([CLI](https://docs.tizen.org/application/tizen-studio/common-tools/command-line-interface)) to create a Tizen or Samsung certificate. To test your app on an actual (watch or TV) device, you have to specify the target device ID (DUID) when creating a Samsung certificate.

- [Creating Certificates - Samsung Developers](https://developer.samsung.com/galaxy-watch-develop/getting-certificates/create.html)
