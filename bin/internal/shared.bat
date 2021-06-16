@ECHO off
REM Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
REM Use of this source code is governed by a BSD-style license that can be
REM found in the LICENSE file.

REM ---------------------------------- NOTE ----------------------------------
REM
REM Please keep the logic in this file consistent with the logic in the
REM `shared.sh` script in the same directory to ensure that Flutter & Dart continue to
REM work across all platforms!
REM
REM --------------------------------------------------------------------------

SETLOCAL ENABLEDELAYEDEXPANSION

SET flutter_repo=https://github.com/flutter/flutter.git

SET cache_dir=%ROOT_DIR%\bin\cache
SET flutter_dir=%ROOT_DIR%\flutter
SET snapshot_path=%ROOT_DIR%\bin\cache\flutter-tizen.snapshot
SET flutter_exe=%flutter_dir%\bin\flutter.bat
SET dart_exe=%flutter_dir%\bin\cache\dart-sdk\bin\dart.exe

SHIFT & CALL :%~1
GOTO :EOF

:update_flutter
  IF EXIST "%flutter_dir%" IF NOT EXIST "%flutter_dir%\.git\" (
    ECHO Error: flutter is not a git directory. Remove it and try again.
    EXIT /B 1
  )

  REM # Clone flutter repo if not installed.
  IF NOT EXIST "%flutter_dir%" (
    git clone --depth=1 "%flutter_repo%" "%flutter_dir%" || (
      ECHO Error: Failed to download the flutter repo from %flutter_repo%.
      EXIT /B
    )
  )

  SETLOCAL
    SET /P version=<"%ROOT_DIR%\bin\internal\flutter.version"

    REM Update flutter repo if needed.    
    PUSHD "%flutter_dir%"
      FOR /f %%r IN ('git rev-parse HEAD') DO SET revision=%%r
      IF !version! NEQ !revision! (
        git reset --hard
        git clean -xdf
        git fetch --depth=1 "%flutter_repo%" "!version!"
        git checkout FETCH_HEAD
      )

      FOR /f %%r IN ('git rev-parse HEAD') DO SET revision=%%r
      IF !version! NEQ !revision! (
        ECHO Error: Something went wrong when upgrading the Flutter SDK.
        ECHO Remove the directory 'flutter' and try again.
        EXIT /B 1
      )
    POPD   

    REM Invalidate the flutter cache.  
    SET stamp_path=%flutter_dir%\bin\cache\flutter_tools.stamp
    IF NOT EXIST "%stamp_path%" GOTO do_flutter_version
    SET /P stamp=<"%stamp_path%"
    IF !version! NEQ !stamp! GOTO do_flutter_version

    EXIT /B
    :do_flutter_version
      CALL "%flutter_exe%" --version || EXIT /B
  ENDLOCAL  
  EXIT /B

:update_flutter_tizen
  IF NOT EXIST "%cache_dir%" MKDIR %cache_dir%

  PUSHD "%ROOT_DIR%"
    FOR /f %%r IN ('git rev-parse HEAD') DO SET revision=%%r
  POPD
  SET stamp_path=%ROOT_DIR%\bin\cache\flutter-tizen.stamp

  SETLOCAL
    IF NOT EXIST "%snapshot_path%" GOTO do_update_snapshot   
    IF NOT EXIST "%stamp_path%" GOTO do_update_snapshot
    SET /P stamp_value=<"%stamp_path%"
    IF !revision! NEQ !stamp_value! GOTO do_update_snapshot
    SET pubspec_yaml_path=%ROOT_DIR%\pubspec.yaml
    SET pubspec_lock_path=%ROOT_DIR%\pubspec.lock
    FOR /F %%i IN ('DIR /B /O:D "%pubspec_yaml_path%" "%pubspec_lock_path%"') DO SET newer_file=%%i
    FOR %%i IN (%pubspec_yaml_path%) DO SET pubspec_yaml_timestamp=%%~ti
    FOR %%i IN (%pubspec_lock_path%) DO SET pubspec_lock_timestamp=%%~ti
    IF "%pubspec_yaml_timestamp%" == "%pubspec_lock_timestamp%" SET newer_file=""
    IF "%newer_file%" EQU "pubspec.yaml" GOTO do_update_snapshot
  ENDLOCAL
  EXIT /B

  :do_update_snapshot
    PUSHD "%ROOT_DIR%"
      ECHO Running pub upgrade...
      CALL "%flutter_exe%" pub upgrade || (
        ECHO Error: Unable to 'pub upgrade' flutter-tizen.
        EXIT /B 1
      )

      ECHO Compiling flutter-tizen...
      CALL "%dart_exe%" --disable-dart-dev --no-enable-mirrors ^
                        --snapshot="%snapshot_path%" --packages="%ROOT_DIR%\.packages" ^
                        "%ROOT_DIR%\bin\flutter_tizen.dart" || (
        ECHO Error: Unable to compile the snapshot.
        EXIT /B 1
      )

      >"%stamp_path%" ECHO %revision%
    POPD
    EXIT /B
  EXIT /B
