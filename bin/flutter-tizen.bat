@ECHO off
REM Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
REM Use of this source code is governed by a BSD-style license that can be
REM found in the LICENSE file.

SETLOCAL ENABLEDELAYEDEXPANSION

REM Test if python3 is installed on the host.
where /q python3 || (
    ECHO Error: Unable to find python3 in your PATH.
    EXIT /B 1
)
python3 -V >NUL 2>NUL
IF errorlevel 9009 (
    ECHO Run "python3" to install python and try again.
    EXIT /B 1
)

REM Run the flutter-tizen python script.
SET FLUTTER_TIZEN_ROOT=%~dp0..
python3 "%FLUTTER_TIZEN_ROOT%\bin\flutter-tizen" %*
EXIT /B !ERRORLEVEL!
