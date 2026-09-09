#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT/buildsystem/macos/apple"
# .NET 8 macOS SDK 15.0.8303 requires Xcode 16.0. Keep this separate from
# the Xcode 16.4 pin used to build native VLC.
sudo xcode-select --switch /Applications/Xcode_16.0.app/Contents/Developer
dotnet --version
dotnet workload install macos --version 8.0.402.1
