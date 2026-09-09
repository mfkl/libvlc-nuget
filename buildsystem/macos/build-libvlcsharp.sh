#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TFMS=net8.0
case "${1:-}" in
    --with-macos)
        cd "$ROOT/buildsystem/macos/apple"
        TFMS='net8.0%3Bnet8.0-macos'
        ;;
    '') ;;
    *) echo 'Usage: build-libvlcsharp.sh [--with-macos]' >&2; exit 1;;
esac
read_version() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$ROOT/buildsystem/macos/versions.json" "$1"; }
SOURCE="$ROOT/.macos-work/libvlcsharp"
if [[ ! -d "$SOURCE/.git" ]]; then
    git clone --depth 1 --branch "$(read_version libvlcsharp_tag)" https://github.com/videolan/libvlcsharp.git "$SOURCE"
fi
[[ $(git -C "$SOURCE" rev-parse HEAD) == "$(read_version libvlcsharp_commit)" ]] || { echo 'Unexpected LibVLCSharp commit' >&2; exit 1; }
PATCH="$ROOT/buildsystem/macos/libvlcsharp-macos-loading.patch"
if git -C "$SOURCE" apply --check "$PATCH"; then
    git -C "$SOURCE" apply "$PATCH"
else
    git -C "$SOURCE" apply --reverse --check "$PATCH"
fi
if [[ "${1:-}" == --with-macos ]]; then
    # Match CLI and project SDK resolution; upstream's global.json selects .NET 10.
    cp "$ROOT/buildsystem/macos/apple/global.json" "$SOURCE/global.json"
fi
dotnet pack "$SOURCE/src/LibVLCSharp/LibVLCSharp.csproj" -c Release \
    -p:TargetFrameworks="$TFMS" -p:GeneratePackageOnBuild=false \
    -p:PackageVersion="$(read_version libvlcsharp_package_version)" \
    -o "$ROOT/.macos-work/packages"
dotnet run --project "$ROOT/buildsystem/macos/loader-tests/LoaderTests.csproj" \
    -p:LoaderAssembly="$SOURCE/src/LibVLCSharp/bin/Release/net8.0/LibVLCSharp.dll"
