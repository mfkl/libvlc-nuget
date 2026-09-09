#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT/buildsystem/macos/apple"
# .NET 8 macOS SDK 15.0.8303 requires Xcode 16.0. Keep this separate from
# the Xcode 16.4 pin used to build native VLC.
# The runner's versioned app path can be a symlink. The pinned Apple SDK passes
# this path to xcrun, which fails to locate tools when Xcode paths disagree.
# https://github.com/dotnet/macios/issues/21762
XCODE_DEVELOPER=$(cd /Applications/Xcode_16.0.app/Contents/Developer && pwd -P)
sudo xcode-select --switch "$XCODE_DEVELOPER"
XCODE_VERSION=$(xcodebuild -version)
echo "$XCODE_DEVELOPER"
echo "$XCODE_VERSION"
[[ ${XCODE_VERSION%%$'\n'*} == 'Xcode 16.0' ]] || exit 1
APPLE_SDK=$(xcrun --sdk macosx --show-sdk-path)
SDKROOT="$APPLE_SDK" xcrun --find install_name_tool
dotnet --version
dotnet workload install macos --version 8.0.402.1
