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

FOR %%i IN ("%~dp0..") DO SET ROOT_DIR=%%~fi

SET shared_bin=%ROOT_DIR%\bin\internal\shared.bat

REM Clone or update the flutter repo.
CALL "%shared_bin%" update_flutter || EXIT /B

REM Upgrade flutter-tizen if needed.
CALL "%shared_bin%" update_flutter_tizen || EXIT /B

REM Run the snapshot.
SET flutter_dir=%ROOT_DIR%\flutter
SET snapshot_path=%ROOT_DIR%\bin\cache\flutter-tizen.snapshot
SET dart_exe=%flutter_dir%\bin\cache\dart-sdk\bin\dart.exe
"%dart_exe%" --disable-dart-dev --packages="%ROOT_DIR%\.dart_tool\package_config.json" "%snapshot_path%" %* & exit /B !ERRORLEVEL!
