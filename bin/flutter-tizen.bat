@ECHO off
REM Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
REM Copyright 2014 The Flutter Authors. All rights reserved.
REM Use of this source code is governed by a BSD-style license that can be
REM found in the LICENSE file.

REM ---------------------------------- NOTE ----------------------------------
REM
REM Please keep the logic in this file consistent with the logic in the
REM `flutter-tizen` script in the same directory to ensure that Flutter continue to
REM work across all platforms!
REM
REM --------------------------------------------------------------------------

SETLOCAL ENABLEDELAYEDEXPANSION

REM Detect which PowerShell executable is available on the Host
REM PowerShell version <= 5: PowerShell.exe
REM PowerShell version >= 6: pwsh.exe
WHERE /Q pwsh.exe && (
  SET powershell_exe=pwsh.exe
) || WHERE /Q PowerShell.exe && (
  SET powershell_exe=PowerShell.exe
) || (
  ECHO Error: PowerShell executable not found.                        1>&2
  ECHO        Either pwsh.exe or PowerShell.exe must be in your PATH. 1>&2
  EXIT 1
)

FOR %%i IN ("%~dp0..") DO SET ROOT_DIR=%%~fi

SET shared_bin=%ROOT_DIR%\bin\internal\shared.bat

REM Clone or update the flutter repo.
CALL "%shared_bin%" update_flutter || EXIT /B

REM Upgrade flutter-tizen if needed.
CALL "%shared_bin%" update_flutter_tizen || EXIT /B

REM Download and extract engine artifacts.
REM The following logic might be re-implemented in Dart in the future.
REM Issue: https://github.com/flutter-tizen/flutter-tizen/issues/77
REM SET update_engine_bin=%ROOT_DIR%\bin\internal\update_engine.ps1
REM %powershell_exe% -ExecutionPolicy Bypass ^
REM  -Command "Unblock-File -Path '%update_engine_bin%'; & '%update_engine_bin%'; exit $LASTEXITCODE;" || EXIT /B

REM Run the snapshot.
SET flutter_dir=%ROOT_DIR%\flutter
SET snapshot_path=%ROOT_DIR%\bin\cache\flutter-tizen.snapshot
SET dart_exe=%flutter_dir%\bin\cache\dart-sdk\bin\dart.exe
"%dart_exe%" --disable-dart-dev --packages="%ROOT_DIR%\.packages" "%snapshot_path%" %* & exit /B !ERRORLEVEL!
