@ECHO off
REM Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
REM Copyright 2014 The Flutter Authors. All rights reserved.
REM Use of this source code is governed by a BSD-style license that can be
REM found in the LICENSE file.

SETLOCAL ENABLEDELAYEDEXPANSION

REM Test if python3 is installed on the host
SET PYTHON_EXE=python3
WHERE %PYTHON_EXE% > NUL 2> NUL
IF !ERRORLEVEL! NEQ 0 (
    ECHO Error: Python3 isn't installed on the host.
    ECHO        The flutter-tizen tool requires python3 to run.
    ECHO        Install Python3 from the official website and try again.
    ECHO        https://www.python.org/downloads/
    EXIT /B !ERRORLEVEL!
)

REM Run flutter-tizen python script
SET FLUTTER_TIZEN_ROOT=%~dp0..
%PYTHON_EXE% "%FLUTTER_TIZEN_ROOT%\bin\flutter-tizen" %*
EXIT /B !ERRORLEVEL!
