# Writing a plugin in C#

This document describes how to write a plugin with C#. The C# plugins can only be used in the C# application project. If you want to create a C++ based application, you have to create a plugin using C++. Please see [Writing a new plugin to use platform features](develop-plugin.md) for more information on creating Tizen plugins using C++ and Dart.


## Create a C# plugin package

To create a C# plugin package, you need to follow the steps below:
```sh
flutter-tizen create --platforms tizen --template plugin --tizen-language csharp [plugin_name]
```
Once the package is created, you will be prompted to add some information to its `pubspec.yaml` file. Open the `pubspec.yaml` file in the directory `[plugin_name]` created by the command above and replace the `some_platform:` map with `tizen:` as suggested by the tool. This information is needed by the flutter-tizen tool to find and register the plugin when building an app that depends on the plugin.

```yaml
You've created a plugin project that doesn't yet support any platforms.
...
Make sure your plugin_name/pubspec.yaml contains the following lines.

flutter:
  plugin:
    platforms:
      tizen:
        namespace: PluginName
        pluginClass: PluginNamePlugin
        fileName: PluginNamePlugin.csproj
```

The created package contains an example app in the `example/` directory. You can run using the following command:
```sh
cd plugin_name/example
flutter-tizen run
```

## Implement the plugin

### 1. Define the package API (`.dart`)

The API of the plugin package is defined in Dart code. Open `lib/plugin_name.dart` file, and then you will see the `platformVersion` property defined in the plugin main class. Invoking this property will invoke the `getPlatformVersion` method through a method channel named `plugin_name`. You have to replace this template code with the actual implementation for your plugin.

Note: This file is not necessary if you're extending an existing plugin for Tizen, so you can safely remove it.

### 2. Add Tizen platform code (`.cs`)

The implementation of the plugin can be found in the `tizen/PluginNamePlugin.cs` file. This file has a `public` class named `PluginNamePlugin` that implements the `IFlutterPlugin` interface. The `IFlutterPlugin` interface is used to handle the lifecycle of the plugin.

- `OnAttachedToEngine(IFlutterPluginBinding binding)`: This method is called when the plugin is registered to the `DotnetPluginRegistry` by the flutter application. In this method, you can create and initialize the platform channel.

  ```c#
  public void OnAttachedToEngine(IFlutterPluginBinding binding)
  {
      _channel = new MethodChannel("plugin_name", StandardMethodCodec.Instance, binding.BinaryMessenger);
      _channel.SetMethodCallHandler(HandleMethodCall);
  }
  ```

- `OnDetachedFromEngine()`: This method is called when the plugin is unregistered from the `DotnetPluginRegistry` by the flutter application. You can release the resources allocated by the platform channel in this method.

  ```c#
  public void OnDetachedFromEngine()
  {
      _channel.UnsetMethodCallHandler();
      _channel = null;
  }
  ```

In case of using `MethodChannel` to communicate with the application, you can set a callback method to handle the method call using `SetMethodCallHandler` method. The callback method can be synchronous or asynchronous.

```c#
// Handle method calls on the plugin's channel.
private object HandleMethodCall(MethodCall call) {
    if (call.Method == "getPlatformVersion") {
        return Foo.GetPlatformVersion();
    }
    throw new MissingPluginException();
}

// Handle method calls on the plugin's channel asynchronously.
private async Task<object> HandleMethodCallAsync(MethodCall call) {
    if (call.Method == "getPlatformVersion") {
        return await Foo.GetPlatformVersionAsync();
    }
    throw new MissingPluginException();
}
```

In the callback method, you can use the `MethodCall` object to get the method name and arguments. If the method is completed successfully, just return any value to the application. If the method failed, throw an exception to the application. Any exception type can be thrown, but `FlutterException` must be used to specify the code and details of the error. The exception will be caught by the `MethodChannel` and the error message will be returned to the application. If the method is not implemented, throw a `MissingPluginException` to the application.


### Available APIs

Like a typical .NET library, the plugin package can use .NET APIs and external NuGet packages. The following APIs are basically available in the plugin package:

- **.NET Standard 2.0**: [.NET Standard 2.0](https://docs.microsoft.com/en-us/dotnet/api/?view=netstandard-2.0) is the default target framework for the plugin package. If you want to use other framework, you can change the `TargetFramework` in the `.csproj` file.
- **Tizen .NET 4.0**: [Tizen .NET](https://github.com/Samsung/TizenFX) is a package that provides the Device APIs for Tizen. You can change the version of the package in the `.csproj` file.
- **Embedding**: [Tizen.Flutter.Embedding](https://github.com/flutter-tizen/flutter-tizen/tree/master/embedding/csharp/Tizen.Flutter.Embedding) is a package that provides the APIs about plugin registration and communication with the flutter application. It is located in the `flutter-tizen/embedding/csharp` directory.


### Channel types

Besides the above mentioned [MethodChannel](../embedding/csharp/Tizen.Flutter.Embedding/Channels/MethodChannel.cs), you can also use other types of platform channels to transfer data between Dart and native code:

- [BasicMessageChannel](../embedding/csharp/Tizen.Flutter.Embedding/Channels/BasicMessageChannel.cs): For basic asynchronous message passing.
- [EventChannel](../embedding/csharp/Tizen.Flutter.Embedding/Channels/EventChannel.cs): For asynchronous event streaming. 
