// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/tizen_plugins.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../src/context.dart';
import '../src/test_flutter_command_runner.dart';

enum PluginType {
  none,
  dart,
  dotnet,
  native,
}

typedef Package = ({
  String name,
  PluginType pluginType,
  List<String> dependencies,
  List<String> devDependencies
});

void main() {
  late FileSystem fileSystem;
  late FlutterProject project;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.file('lib/main.dart').createSync(recursive: true);
  });

  String snakeToCamel(String snakeCase) {
    final List<String> parts = snakeCase.split('_');
    if (parts.isEmpty) {
      return snakeCase;
    }
    final Iterable<String> capitalizedParts = parts.map((part) {
      if (part.isEmpty) {
        return '';
      }
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    });

    return capitalizedParts.join();
  }

  String getPubspecString(Package package) {
    final PluginType type = package.pluginType;
    var platformsField = '';
    if (type == PluginType.dart) {
      platformsField = '''
flutter:
  plugin:
    platforms:
      tizen:
        dartPluginClass: ${snakeToCamel(package.name)}
        fileName: ${package.name}.dart
''';
    } else if (type == PluginType.dotnet) {
      platformsField = '''
flutter:
  plugin:
    platforms:
      tizen:
        namespace: ${snakeToCamel(package.name)}
        pluginClass: ${snakeToCamel(package.name)}
        fileName: ${snakeToCamel(package.name)}.csproj
''';
    } else if (type == PluginType.native) {
      platformsField = '''
flutter:
  plugin:
    platforms:
      tizen:
        pluginClass: ${snakeToCamel(package.name)}
        fileName: ${package.name}.h
''';
    }

    return '''
name: ${package.name}
$platformsField
dependencies:
${package.dependencies.map((String d) => '  $d: {path: $d}').join('\n')}
dev_dependencies:
${package.devDependencies.map((String d) => '  $d: {path: $d}').join('\n')}
''';
  }

  /// Source: [writePubspecs] in `package_graph_test.dart`
  void writePubspecs(List<Package> graph) {
    final packageConfigMap = <String, Object?>{'configVersion': 2};
    for (final package in graph) {
      fileSystem.file(fileSystem.path
          .join(package.pluginType != PluginType.none ? package.name : '', 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync(getPubspecString(package));
      ((packageConfigMap['packages'] ??= <Object?>[]) as List<Object?>).add(<String, Object?>{
        'name': package.name,
        'rootUri': '../${package.pluginType != PluginType.none ? package.name : ''}',
        'packageUri': 'lib/',
        'languageVersion': '3.7',
      });
    }
    fileSystem.file(fileSystem.path.join('.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(packageConfigMap));
  }

  /// Source: [writePackageGraph] in `package_graph_test.dart`
  void writePackageGraph(List<Package> graph) {
    fileSystem.file(fileSystem.path.join('.dart_tool', 'package_graph.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode(<String, Object?>{
          'configVersion': 1,
          'packages': <Object?>[
            for (final Package package in graph)
              <String, Object?>{
                'name': package.name,
                'dependencies': package.dependencies,
                'devDependencies': package.devDependencies,
              },
          ],
        }),
      );
  }

  /// Source: [validatesComputeTransitiveDependencies] in `package_graph_test.dart`
  Future<void> validatesComputeTransitiveDependencies(
    List<Package> graph,
  ) async {
    writePubspecs(graph);
    writePackageGraph(graph);
  }

  testUsingContext('Does not include dev_dependency Dart plugins in registrant', () async {
    final command = _DummyFlutterCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);

    fileSystem.file('tizen/tizen-manifest.xml').createSync(recursive: true);

    await validatesComputeTransitiveDependencies(<Package>[
      (
        name: 'my_app',
        pluginType: PluginType.none,
        dependencies: <String>['some_dart_plugin'],
        devDependencies: <String>['some_dev_dart_plugin'],
      ),
      (
        name: 'some_dart_plugin',
        pluginType: PluginType.dart,
        dependencies: <String>[],
        devDependencies: <String>[],
      ),
      (
        name: 'some_dev_dart_plugin',
        pluginType: PluginType.dart,
        dependencies: <String>[],
        devDependencies: <String>[],
      ),
    ]);

    await runner.run(<String>['dummy']);

    final File generatedMain = fileSystem.file('tizen/flutter/generated_main.dart');
    expect(generatedMain, exists);

    final String contents = generatedMain.readAsStringSync();
    expect(contents, contains("import 'package:some_dart_plugin/some_dart_plugin.dart';"));
    expect(contents,
        isNot(contains("import 'package:some_dev_dart_plugin/some_dev_dart_plugin.dart';")));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  }, testOn: 'posix');

  testUsingContext('Generates Dart plugin registrant', () async {
    final command = _DummyFlutterCommand();
    final CommandRunner<void> runner = createTestCommandRunner(command);

    fileSystem.file('tizen/tizen-manifest.xml').createSync(recursive: true);

    await validatesComputeTransitiveDependencies(<Package>[
      (
        name: 'my_app',
        pluginType: PluginType.none,
        dependencies: <String>['some_dart_plugin'],
        devDependencies: <String>[],
      ),
      (
        name: 'some_dart_plugin',
        pluginType: PluginType.dart,
        dependencies: <String>[],
        devDependencies: <String>[],
      ),
    ]);
    await runner.run(<String>['dummy']);

    final File generatedMain = fileSystem.file('tizen/flutter/generated_main.dart');
    expect(generatedMain, exists);
    expect(generatedMain.readAsStringSync(), contains('''
import 'package:some_dart_plugin/some_dart_plugin.dart';
import 'package:flutter/src/dart_plugin_registrant.dart';

@pragma('vm:entry-point')
class _PluginRegistrant {
  @pragma('vm:entry-point')
  static void register() {
    SomeDartPlugin.register();
  }
}
'''));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  }, testOn: 'posix');

  testUsingContext('Generates native plugin registrant for C++', () async {
    fileSystem.file('tizen/tizen-manifest.xml').createSync(recursive: true);

    await validatesComputeTransitiveDependencies(<Package>[
      (
        name: 'my_app',
        pluginType: PluginType.none,
        dependencies: <String>['some_native_plugin'],
        devDependencies: <String>[],
      ),
      (
        name: 'some_native_plugin',
        pluginType: PluginType.native,
        dependencies: <String>[],
        devDependencies: <String>[],
      ),
    ]);
    project = FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);
    await injectTizenPlugins(project);

    final File cppPluginRegistrant = fileSystem.file('tizen/flutter/generated_plugin_registrant.h');
    expect(cppPluginRegistrant, exists);
    expect(cppPluginRegistrant.readAsStringSync(), contains('''
#include "some_native_plugin.h"

// Registers Flutter plugins.
void RegisterPlugins(flutter::PluginRegistry *registry) {
  SomeNativePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SomeNativePlugin"));
}
'''));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  }, testOn: 'posix');

  testUsingContext('Generates native plugin registrant for C#', () async {
    fileSystem.file('tizen/Runner.csproj').createSync(recursive: true);
    fileSystem.file('tizen/tizen-manifest.xml').createSync(recursive: true);

    final Directory pluginDir = fileSystem.directory('/some_native_plugin');
    await validatesComputeTransitiveDependencies(<Package>[
      (
        name: 'my_app',
        pluginType: PluginType.none,
        dependencies: <String>['some_native_plugin'],
        devDependencies: <String>[],
      ),
      (
        name: 'some_native_plugin',
        pluginType: PluginType.native,
        dependencies: <String>[],
        devDependencies: <String>[],
      ),
    ]);
    pluginDir.childFile('tizen/project_def.prop')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
APPNAME = some_native_plugin
type = staticLib
''');
    project = FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);
    await injectTizenPlugins(project);

    final File csharpPluginRegistrant =
        fileSystem.file('tizen/flutter/GeneratedPluginRegistrant.cs');
    expect(csharpPluginRegistrant, exists);
    expect(csharpPluginRegistrant.readAsStringSync(), contains('''
internal class GeneratedPluginRegistrant
{
    [DllImport("flutter_plugins.so")]
    public static extern void SomeNativePluginRegisterWithRegistrar(
        FlutterDesktopPluginRegistrar registrar);

    public static void RegisterPlugins(IPluginRegistry registry)
    {
        SomeNativePluginRegisterWithRegistrar(
            registry.GetRegistrarForPlugin("SomeNativePlugin"));
    }
}
'''));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  }, testOn: 'posix');

  testUsingContext('Generates .NET plugin registrant for C#', () async {
    fileSystem.file('tizen/Runner.csproj').createSync(recursive: true);
    fileSystem.file('tizen/tizen-manifest.xml').createSync(recursive: true);

    final Directory pluginDir = fileSystem.directory('/some_dotnet_plugin');
    await validatesComputeTransitiveDependencies(<Package>[
      (
        name: 'my_app',
        pluginType: PluginType.none,
        dependencies: <String>['some_dotnet_plugin'],
        devDependencies: <String>[],
      ),
      (
        name: 'some_dotnet_plugin',
        pluginType: PluginType.dotnet,
        dependencies: <String>[],
        devDependencies: <String>[],
      ),
    ]);
    project = FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);
    await injectTizenPlugins(project);

    final File csharpPluginRegistrant =
        fileSystem.file('tizen/flutter/GeneratedPluginRegistrant.cs');
    expect(csharpPluginRegistrant, exists);
    expect(csharpPluginRegistrant.readAsStringSync(), contains('''
internal class GeneratedPluginRegistrant
{
    public static void RegisterPlugins(IPluginRegistry registry)
    {
        DotnetPluginRegistry.Instance.AddPlugin(
            new global::SomeDotnetPlugin.SomeDotnetPlugin());
    }
}
'''));

    final File dotnetIntermediateTarget =
        fileSystem.file('tizen/obj/Runner.csproj.flutter.targets');
    expect(dotnetIntermediateTarget, exists);
    expect(dotnetIntermediateTarget.readAsStringSync(), contains('''
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<Project ToolsVersion="14.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
    <ProjectReference Include="${pluginDir.path}/tizen/SomeDotnetPlugin.csproj" />
  </ItemGroup>
</Project>
'''));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  }, testOn: 'posix');

  testUsingContext('Generates .NET plugin registrants for C# multi', () async {
    fileSystem.file('tizen/ui/Runner.csproj').createSync(recursive: true);
    fileSystem.file('tizen/ui/tizen-manifest.xml').createSync(recursive: true);
    fileSystem.file('tizen/service/RunnerService.csproj').createSync(recursive: true);
    fileSystem.file('tizen/service/tizen-manifest.xml').createSync(recursive: true);

    await validatesComputeTransitiveDependencies(<Package>[
      (
        name: 'my_app',
        pluginType: PluginType.none,
        dependencies: <String>['some_dotnet_plugin'],
        devDependencies: <String>[],
      ),
      (
        name: 'some_dotnet_plugin',
        pluginType: PluginType.dotnet,
        dependencies: <String>[],
        devDependencies: <String>[],
      ),
    ]);
    project = FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);
    await injectTizenPlugins(project);

    final intermediateFiles = <File>[
      fileSystem.file('tizen/ui/flutter/GeneratedPluginRegistrant.cs'),
      fileSystem.file('tizen/ui/obj/Runner.csproj.flutter.targets'),
      fileSystem.file('tizen/service/flutter/GeneratedPluginRegistrant.cs'),
      fileSystem.file('tizen/service/obj/RunnerService.csproj.flutter.targets'),
    ];
    for (final file in intermediateFiles) {
      expect(file, exists);
    }
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  }, testOn: 'posix');

  testUsingContext('Generates plugins & extra info file for C++', () async {
    fileSystem.file('tizen/tizen-manifest.xml').createSync(recursive: true);

    await validatesComputeTransitiveDependencies(<Package>[
      (
        name: 'my_app',
        pluginType: PluginType.none,
        dependencies: <String>['some_native_plugin'],
        devDependencies: <String>[],
      ),
      (
        name: 'some_native_plugin',
        pluginType: PluginType.native,
        dependencies: <String>[],
        devDependencies: <String>[],
      ),
    ]);
    project = FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);
    await injectTizenPlugins(project);

    final File appDepsJson = fileSystem.file('tizen/.app.deps.json');
    expect(appDepsJson, exists);
    expect(appDepsJson.readAsStringSync(), contains('''
  "info": "This is a generated file; do not edit or check into version control.",
  "plugins": [
    {
      "name": "some_native_plugin",
      "version": ""
    }
  ],
'''));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  }, testOn: 'posix');

  testUsingContext('Generates plugins & extra info file for C#', () async {
    fileSystem.file('tizen/Runner.csproj').createSync(recursive: true);
    fileSystem.file('tizen/tizen-manifest.xml').createSync(recursive: true);

    await validatesComputeTransitiveDependencies(<Package>[
      (
        name: 'my_app',
        pluginType: PluginType.none,
        dependencies: <String>['some_native_plugin'],
        devDependencies: <String>[],
      ),
      (
        name: 'some_native_plugin',
        pluginType: PluginType.native,
        dependencies: <String>[],
        devDependencies: <String>[],
      ),
    ]);
    fileSystem.directory('/some_native_plugin').childFile('tizen/project_def.prop')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
APPNAME = some_native_plugin
type = staticLib
''');
    project = FlutterProject.fromDirectoryTest(fileSystem.currentDirectory);
    await injectTizenPlugins(project);

    final File appDepsJson = fileSystem.file('tizen/.app.deps.json');
    expect(appDepsJson, exists);
    expect(appDepsJson.readAsStringSync(), contains('''
  "info": "This is a generated file; do not edit or check into version control.",
  "plugins": [
    {
      "name": "some_native_plugin",
      "version": ""
    }
  ],
'''));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  }, testOn: 'posix');
}

class _DummyFlutterCommand extends FlutterCommand with DartPluginRegistry {
  _DummyFlutterCommand() {
    usesTargetOption();
  }

  @override
  var name = 'dummy';

  @override
  var description = '';

  @override
  Future<FlutterCommandResult> runCommand() async {
    return const FlutterCommandResult(ExitStatus.success);
  }
}
