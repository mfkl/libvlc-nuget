#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
VERSION=$(python3 -c 'import json; print(json.load(open("buildsystem/macos/versions.json"))["package_version"])')
for rid in osx-x64 osx-arm64; do
    test -f "build/macos/$rid/lib/libvlc.dylib"
    test -f "build/macos/$rid/lib/libvlccore.dylib"
    test -f "build/macos/$rid/build-manifest.json"
done
mkdir -p .macos-work/packages
nuget pack VideoLAN.LibVLC.Mac.nuspec -Version "$VERSION" -OutputDirectory .macos-work/packages
