# Debugging the flutter-tizen tool

The flutter-tizen tool is written in Dart. It extends the original [Flutter CLI](https://github.com/flutter/flutter/tree/master/packages/flutter_tools)'s functionality by (basically) overriding some of its classes and methods at the code level.

- The flutter-tizen tool creates its snapshot (compiled Dart code) when it's run for the first time. To run the tool directly from source, run this in the repository root:

  ```sh
  dart bin/flutter_tizen.dart --flutter-root flutter [command]
  ```

- To force the snapshot to be re-generated, remove `bin/cache/flutter-tizen.snapshot`.

- To debug the tool with the VS Code debugger, install the [Dart extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.dart-code) and configure `launch.json` as follows:

  ```json
  {
    "name": "flutter-tizen",
    "request": "launch",
    "type": "dart",
    "cwd": "<target project directory>",
    "program": "<flutter-tizen repo root>/bin/flutter_tizen.dart",
    "args": ["--flutter-root", "<flutter-tizen repo root>/flutter", "[command]"]
  }
  ```
