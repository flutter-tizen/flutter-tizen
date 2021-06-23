# Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# ---------------------------------- NOTE ---------------------------------- #
#
# Please keep the logic in this file consistent with the logic in the
# `update_engine.sh` script in the same directory to ensure that Flutter
# continues to work across all platforms!
#
# -------------------------------------------------------------------------- #

$ErrorActionPreference = "Stop"

$progName = Split-Path -parent $MyInvocation.MyCommand.Definition
$rootPath = (Get-Item $progName).parent.parent.FullName
$enginePath = "$rootPath\bin\cache\artifacts\engine"
$engineStamp = "$enginePath\engine.stamp"
$engineVersion = (Get-Content "$rootPath\bin\internal\engine.version")
$engineShortVersion = $engineVersion.Substring(0, 7)

# Make sure that PowerShell has expected version.
$psMajorVersionRequired = 5
$psMajorVersionLocal = $PSVersionTable.PSVersion.Major
if ($psMajorVersionLocal -lt $psMajorVersionRequired) {
    Write-Host "Flutter requires PowerShell $psMajorVersionRequired.0 or newer."
    Write-Host "See https://flutter.dev/docs/get-started/install/windows for more."
    Write-Host "Current version is $psMajorVersionLocal."
    exit 1
}

if ((Test-Path $engineStamp) -and ($engineVersion -eq (Get-Content $engineStamp))) {
    return
}

# Clear bin/cache/artifacts/engine directory before updating.
Remove-Item -Recurse -Force "$enginePath" -ErrorAction SilentlyContinue
New-Item $enginePath -force -type directory | Out-Null

$engineBaseUrl = $ENV:BASE_URL
if (-not $engineBaseUrl) {
    $engineBaseUrl = "https://github.com/flutter-tizen/engine/releases"
}
$engineZipName = "windows-x64.zip"
$engineUrl = "$engineBaseUrl/download/$engineShortVersion/$engineZipName"
$engineZipPath = "$enginePath\artifacts.zip"

Try {
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $engineUrl -Destination $engineZipPath -ErrorAction Stop
}
Catch {
    Write-Host "Downloading the flutter-tizen engine using the BITS service failed, retrying with WebRequest..."
    Invoke-WebRequest -Uri $engineUrl -OutFile $engineZipPath
}

Write-Host "Expanding downloaded archive..."
If (Get-Command 7z -errorAction SilentlyContinue) {
    # The built-in unzippers are painfully slow. Use 7-Zip, if available.
    & 7z x $engineZipPath "-o$enginePath" -bd | Out-Null
} ElseIf (Get-Command 7za -errorAction SilentlyContinue) {
    # Use 7-Zip's standalone version 7za.exe, if available.
    & 7za x $engineZipPath "-o$enginePath" -bd | Out-Null
} ElseIf (Get-Command Microsoft.PowerShell.Archive\Expand-Archive -errorAction SilentlyContinue) {
    # Use PowerShell's built-in unzipper, if available (requires PowerShell 5+).
    Microsoft.PowerShell.Archive\Expand-Archive $engineZipPath -DestinationPath $enginePath
} Else {
    # As last resort: fall back to the Windows GUI.
    $shell = New-Object -com shell.application
    $zip = $shell.NameSpace($engineZipPath)
    foreach($item in $zip.items()) {
        $shell.Namespace($enginePath).copyhere($item)
    }
}

Remove-Item $engineZipPath
$engineVersion | Out-File $engineStamp -Encoding ASCII
