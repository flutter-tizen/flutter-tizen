# Debugging the flutter-tizen tool

The flutter-tizen tool is written in Dart. It extends the original [Flutter CLI](https://github.com/flutter/flutter/tree/master/packages/flutter_tools)'s functionality by (basically) overriding some of its classes and methods at the code level.

- The flutter-tizen tool creates its snapshot (compiled Dart code) when it's run for the first time. To run the tool directly from source, run this in the repository root:

  ```sh
  flutter/bin/dart bin/flutter_tizen.dart help
  ```

- To force the snapshot to be re-generated, remove `bin/cache/flutter-tizen.snapshot`.

- To debug the tool with the VS Code debugger,
  1. Add `flutter-tizen` directory to your workspace.
  2. Install the [Dart extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.dart-code) for VS Code.
  3. Configure `launch.json` file as follows:<p>
     ```json
     {
       "version": "0.2.0",
       "configurations": [
         {
           "name": "flutter-tizen",
           "request": "launch",
           "type": "dart",
           "cwd": "${fileWorkspaceFolder}",
           "program": "${workspaceFolder}/bin/flutter_tizen.dart",
           "args": ["doctor"]
         }
       ]
     }
     ```
  4. Start debugging (F5).
