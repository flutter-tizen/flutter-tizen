#!/usr/bin/env bash
# Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# ---------------------------------- NOTE ---------------------------------- #
#
# Please keep the logic in this file consistent with the logic in the
# `update_engine.ps1` script in the same directory to ensure that Flutter continue
# to work across all platforms!
#
# -------------------------------------------------------------------------- #

set -e

ROOT_DIR="$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")"
ENGINE_DIR="$ROOT_DIR/bin/cache/artifacts/engine"
ENGINE_BASE_URL="https://github.com/flutter-tizen/engine/releases"
ENGINE_STAMP="$ENGINE_DIR/engine.stamp"
ENGINE_VERSION="$(cat "$ROOT_DIR/bin/internal/engine.version")"

mkdir -p "$ENGINE_DIR"

if [[ ! -f "$ENGINE_STAMP" || "$ENGINE_VERSION" != "$(cat "$ENGINE_STAMP")" ]]; then
  command -v curl > /dev/null 2>&1 || {
    >&2 echo
    >&2 echo 'Missing "curl" tool. Unable to download the engine artifacts.'
    case "$(uname -s)" in
      Darwin)
        >&2 echo 'Consider running "brew install curl".'
        ;;
      Linux)
        >&2 echo 'Consider running "sudo apt-get install curl".'
        ;;
      *)
        >&2 echo "Please install curl."
        ;;
    esac
    echo
    exit 1
  }
  command -v unzip > /dev/null 2>&1 || {
    >&2 echo
    >&2 echo 'Missing "unzip" tool. Unable to extract the engine artifacts.'
    case "$(uname -s)" in
      Darwin)
        echo 'Consider running "brew install unzip".'
        ;;
      Linux)
        echo 'Consider running "sudo apt-get install unzip".'
        ;;
      *)
        echo "Please install unzip."
        ;;
    esac
    echo
    exit 1
  }

  echo "Updating the engine artifacts for flutter-tizen..."

  case "$(uname -s)" in
    Darwin)
      ENGINE_ZIP_NAME="darwin-x64.zip"
      ;;
    Linux)
      ENGINE_ZIP_NAME="linux-x64.zip"
      ;;
    *)
      echo "Unknown operating system. Cannot download flutter-tizen engines."
      exit 1
      ;;
  esac

  # Overwrite ENGINE_BASE_URL if BASE_URL environment variable is set.
  if [[ -n "$BASE_URL" ]]; then
      ENGINE_BASE_URL="$BASE_URL"
  fi

  ENGINE_URL="$ENGINE_BASE_URL/download/${ENGINE_VERSION:0:7}/$ENGINE_ZIP_NAME"
  ENGINE_ZIP_PATH="$ENGINE_DIR/artifacts.zip"

  curl --retry 3 --continue-at - --location --output "$ENGINE_ZIP_PATH" "$ENGINE_URL" 2>&1 || {
      >&2 echo
      >&2 echo "Failed to download the engine artifacts from: $ENGINE_URL"
      >&2 echo
      rm -f -- "$ENGINE_ZIP_PATH"
      exit 1
  }

  unzip -o -q "$ENGINE_ZIP_PATH" -d "$ENGINE_DIR" || {
      >&2 echo
      >&2 echo "Unable to extact the engine artifacts. check the URL is valid:"
      >&2 echo "  $ENGINE_URL"
      >&2 echo
      rm -f -- "$ENGINE_ZIP_PATH"
      exit 1
  }

  rm -f -- "$ENGINE_ZIP_PATH"
  find "$ENGINE_DIR" -type d -exec chmod 755 {} \;
  find "$ENGINE_DIR" -type f -name gen_snapshot -exec chmod a+x,a+r {} \;

  echo "$ENGINE_VERSION" > "$ENGINE_STAMP"
fi
