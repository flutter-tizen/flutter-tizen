# Writing a new plugin to use platform features

This document helps you understand how to get started with developing Flutter plugins for Tizen devices. This document assumes you already have basic understanding of [**how plugins are different from general Dart packages**](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#types) and [**how platform channels work in Flutter**](https://flutter.dev/docs/development/platform-integration/platform-channels).

## Overview

Here are a few things you might consider when developing Flutter plugins for Tizen (and other platforms).

### Implementation language

- C++ or C# (using platform channels)
- Dart (using Dart FFI)

Typical Flutter plugins are written in their platform native languages, such as Java on Android and C++ on Tizen. However, some Windows plugins such as [`path_provider_windows`](https://github.com/flutter/plugins/tree/main/packages/path_provider/path_provider_windows) and Tizen plugins such as [`path_provider_tizen`](https://github.com/flutter-tizen/plugins/tree/master/packages/path_provider) are written in pure Dart using [Dart FFI](https://dart.dev/guides/libraries/c-interop) without any native code.

This document only covers native Tizen plugins written in C++. To learn more about FFI-based plugins on other platforms, you might read [Flutter Docs: Binding to native Android code using dart:ffi](https://docs.flutter.dev/development/platform-integration/android/c-interop). If you want to learn how to write a native plugin in C#, you might read [Writing a plugin in C#](develop-plugin-csharp.md).

### Targeting multiple platforms vs. Tizen only

A Flutter plugin may support more than one platforms. For example, each of the [Flutter 1st-party plugins](https://github.com/flutter/plugins) developed by the Flutter team supports at least two (Android, iOS) or more platforms (web, macOS, Windows, Linux), based on the team's priority and the availability of the functionality on the platforms. [Federated plugins](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#federated-plugins) are a way of splitting support for different platforms into separate packages. A federated plugin consists of an app-facing package, a **platform interface package**, and platform package(s) for each platform.

On the other hand, it is also possible for a plugin to support only a single particular platform, e.g. [`flutter_plugin_android_lifecycle`](https://pub.dev/packages/flutter_plugin_android_lifecycle) for Android and [`tizen_app_control`](https://pub.dev/packages/tizen_app_control) for Tizen. In this case, there's no need to create a platform interface package. Instead, you can put everything into a single package.

### Extending existing plugins vs. Creating new plugins

Adding a new platform support to an existing plugin is simple: create a platform package that implements the platform interface of the plugin. It is technically not required for the original plugin author to _endorse_ your new platform implementation. A developer can use the unendorsed platform implementation in their app, but must specify both package dependencies in the app's pubspec file. For example, if there is a `foobar_tizen` implementation for the `foobar` plugin, the app's pubspec file must include both the `foobar` and `foobar_tizen` dependencies, unless the original `foobar` author adds `foobar_tizen` as a dependency in the pubspec of `foobar`.

Note: Even if the original plugin is not a federated plugin (has no platform interface package), it is possible to create an unendorsed platform implementation of the plugin by implicitly implementing the plugin's platform channels.

You can also create a new plugin from scratch, if the functionality you want to implement is not implemented by any other plugin, or is specific to Tizen. The new plugin can be either a single package plugin or a federated plugin, depending on whether you want to target the Tizen platform only or other platforms as well.

## Create a plugin package

If you're to extend an existing plugin for Tizen, it is common to add the `_tizen` suffix to the package name:

```sh
flutter-tizen create --platforms tizen --template plugin foobar_tizen
```

Otherwise, follow the `lowercase_with_underscores` style convention to name your package:

```sh
flutter-tizen create --platforms tizen --template plugin plugin_name
```

Once the package is created, you will be prompted to add some information to its pubspec file. Open the main `plugin_name/` directory in VS Code, locate the `pubspec.yaml` file, and replace the `some_platform:` map with `tizen:` as suggested by the tool. This information is needed by the flutter-tizen tool to find and register the plugin when building an app that depends on the plugin.

```yaml
You've created a plugin project that doesn't yet support any platforms.
...
Make sure your plugin_name/pubspec.yaml contains the following lines.

flutter:
  plugin:
    platforms:
      tizen:
        pluginClass: PluginNamePlugin
        fileName: plugin_name_plugin.h
```

The created package contains an example app in the `example/` directory. You can run it using the `flutter-tizen run` command:

```sh
$ cd plugin_name/example
$ flutter-tizen run
```

## Implement the plugin

### 1. Define the package API (`.dart`)

The API of the plugin package is defined in Dart code. Open the `lib/plugin_name.dart` file in VS Code, and then you will see the `getPlatformVersion` method defined in the plugin's main class. Invoking this method will eventually invoke the method channel method `getPlatformVersion` defined in the `plugin_name_method_channel.dart` file. You have to replace this template code with the actual implementation for your plugin.

Note: You don't need these Dart files if you're extending an existing plugin for Tizen, so you can safely remove them.

### 2. Add Tizen platform code (`.cc`)

Note: Before getting started, you may apply [recommended settings for plugin developers](https://github.com/flutter-tizen/flutter-tizen/wiki/Recommended-settings-for-VS-Code#plugin-developer) in VS Code.

The implementation of the plugin can be found in the `tizen/src/plugin_name_plugin.cc` file. In this file, you will see:

- `PluginNamePluginRegisterWithRegistrar()`: This function is called by an app that depends on this plugin on startup to set up the `plugin_name` channel.
- `HandleMethodCall()`: This method handles the `getPlatformVersion` method (or whatever methods you defined in Dart code) and returns the result to the caller.

The result of the method call can be either:

- `Success()`: Indicates that the call completed successfully. The argument can be either empty or of the `flutter::EncodableValue` type.
- `Error()`: Indicates that the call was understood but handling failed in some way. The error can be caught as a `PlatformException` by the caller.
- `NotImplemented()`

Arguments to the method call can be retrieved from the `method_call` variable. For example, if a `map<String, dynamic>` is passed from Dart code like:

```dart
await _channel.invokeMethod<void>(
  'create',
  <String, dynamic>{'cameraName': name},
);
```

then it can be parsed as a `flutter::EncodableMap` in C++ code as follows:

```cpp
template <typename T>
static bool GetValueFromEncodableMap(const flutter::EncodableMap *map,
                                     const char *key, T &out) {
  auto iter = map->find(flutter::EncodableValue(key));
  if (iter != map->end() && !iter->second.IsNull()) {
    if (auto *value = std::get_if<T>(&iter->second)) {
      out = *value;
      return true;
    }
  }
  return false;
}

void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto &method_name = method_call.method_name();

  if (method_name == "create") {
    const auto *arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("Invalid arguments", "Invalid argument type.");
      return;
    }
    std::string camera_name;
    if (!GetValueFromEncodableMap(arguments, "cameraName", camera_name)) {
      result->Error("Invalid arguments", "No cameraName provided.");
      return;
    }
    // The implementation goes here.
    ...
    result->Success();
  }
}
```

Make sure either `Success`, `Error`, or `NotImplemented` is called on `result` after the method call is handled (otherwise, the `Future` returned by `MethodChannel.invokeMethod` will remain uncompleted forever). Note that the result can be passed either synchronously or asynchronously (e.g. from a callback) as long as the ownership of `result` is retained properly.

### Supported data types

The standard platform channels use a standard message codec that supports efficient binary serialization of simple JSON-like values, such as booleans, numbers, Strings, byte buffers, and Lists and Maps of these (see [`StandardMessageCodec`](https://api.flutter.dev/flutter/services/StandardMessageCodec-class.html) for details). The following table shows how Dart types are mapped with `flutter::EncodableValue` variant types on the platform side.

| Dart | C++ |
|-|-|
| `null` | `std::monostate` |
| `bool` | `bool` |
| `int` | `int32_t` or `int64_t` |
| `double` | `double` |
| `String` | `std::string` |
| `Uint8List` | `std::vector<uint8_t>` |
| `Int32List` | `std::vector<int32_t>` |
| `Int64List` | `std::vector<int64_t>` |
| `Float64List` | `std::vector<double>` |
| `List` | `flutter::EncodableList` |
| `Map` | `flutter::EncodableMap` |

### Available APIs

Types such as `flutter::MethodCall` and `flutter::EncodableValue` in the template code are defined in [cpp_client_wrapper](https://github.com/flutter-tizen/engine/tree/HEAD/shell/platform/common/client_wrapper/include/flutter) headers. APIs that you can use in your plugin code include:

- C++17 standards
- [cpp_client_wrapper](https://github.com/flutter-tizen/engine/tree/HEAD/shell/platform/common/client_wrapper/include/flutter)
- [Tizen native APIs](https://docs.tizen.org/application/native/api/common/latest/index.html)
- External native libraries, if any (static/shared)

Note: The API references for Tizen TV are not publicly available. However, most of the Tizen common APIs are also available for the TV profile, so you may refer to the common API references when developing plugins for TV devices.

### Channel types

Besides the above mentioned [MethodChannel](https://api.flutter.dev/flutter/services/MethodChannel-class.html), you can also use other types of platform channels to transfer data between Dart and native code:

- [BasicMessageChannel](https://api.flutter.dev/flutter/services/BasicMessageChannel-class.html): For basic asynchronous message passing.
- [EventChannel](https://api.flutter.dev/flutter/services/EventChannel-class.html): For asynchronous event streaming.

### Tizen privileges

If any privileges are required to run your plugin code, you have to list them in the plugin's README so that app developers can properly add them to their `tizen-manifest.xml`.

If one or more privileges are [privacy-related privileges](https://docs.tizen.org/application/dotnet/get-started/api-privileges), permissions must be granted by user at runtime. To request permissions at runtime, use the [Privacy Privilege Manager API](https://docs.tizen.org/application/native/guides/security/privacy-related-permissions) ([example](https://github.com/flutter-tizen/plugins/blob/master/packages/image_picker/tizen/src/permission_manager.cc)).

On TV devices, permissions are already granted to apps by default. Invoking permission-related APIs will result in a library loading error on TV devices. If you want to run your plugin on different types of devices using a single codebase, consider using the `TV_PROFILE` macro to separate the TV-specific code ([example](https://github.com/flutter-tizen/plugins/blob/master/packages/image_picker/tizen/src/permission_manager.cc)).

## Publish the plugin

To share your plugin with other developers, you can publish it on [pub.dev](https://pub.dev). You may refer to the following pages for detailed instructions.

- [Flutter Docs: Publishing your package](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#publish)
- [Dart Docs: Publishing packages](https://dart.dev/tools/pub/publishing)

Note: You can use the `flutter-tizen pub` command instead of `flutter pub` if `flutter` is not in your PATH.
