#!/usr/bin/env bash
# Builds the smoke app against the packages in a folder and runs it on this Mac.
# The folder holds VideoLAN.LibVLC.Mac(.GPL) and a LibVLCSharp with the macOS loader fix.
set -euo pipefail
USAGE="Usage: test.sh <package folder> [net8.0|net9.0-macos|...] [VideoLAN.LibVLC.Mac|VideoLAN.LibVLC.Mac.GPL]"
PACKAGES=$(cd "${1:?$USAGE}" && pwd)
TFM=${2:-net8.0}
PACKAGE=${3:-VideoLAN.LibVLC.Mac}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
cat > "$OUT/NuGet.Config" <<XML
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="$PACKAGES" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="local">
      <package pattern="VideoLAN.LibVLC.Mac*" />
      <package pattern="LibVLCSharp" />
    </packageSource>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
XML
# Packages keep their version between rebuilds, so never reuse a cached copy.
export NUGET_PACKAGES="$OUT/packages"
ARGS=(-p:SmokeTargetFramework="$TFM" -p:SmokeLibVLCPackage="$PACKAGE" -p:RestoreConfigFile="$OUT/NuGet.Config")
rm -rf "$HERE/obj" "$HERE/bin"

if [[ "$TFM" != *-macos* ]]; then
    dotnet build "$HERE/Smoke.csproj" "${ARGS[@]}" -o "$OUT/portable"
    dotnet "$OUT/portable/Smoke.dll"
else
    RID=$([[ $(uname -m) == arm64 ]] && echo osx-arm64 || echo osx-x64)
    # Keep the default output path: the Apple SDK mangles an OutputPath outside
    # the project's directory tree, leaving an app bundle without its executable.
    dotnet build "$HERE/Smoke.csproj" "${ARGS[@]}" -c Release -r "$RID"
    "$HERE/bin/Release/$TFM/$RID/Smoke.app/Contents/MacOS/Smoke"
fi
