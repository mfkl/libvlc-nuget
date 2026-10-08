#!/usr/bin/env bash
# Builds the smoke app against the packages in a folder and runs it.
set -euo pipefail
RID=${1:?Usage: test.sh osx-x64|osx-arm64 net8.0|net8.0-macos <package folder>}
TFM=${2:?Specify net8.0 or net8.0-macos}
PACKAGES=$(cd "${3:?Specify the folder holding the .nupkg files}" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/../../.macos-work/smoke-$RID-$TFM"
cd "$HERE"
rm -rf "$OUT" obj
mkdir -p "$OUT"
cat > "$OUT.NuGet.Config" <<XML
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="$PACKAGES" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="local">
      <package pattern="VideoLAN.LibVLC.Mac" />
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
ARGS=(-p:SmokeTargetFramework="$TFM" -p:RestoreConfigFile="$OUT.NuGet.Config")

if [[ "$TFM" == net8.0 ]]; then
    dotnet build Smoke.csproj "${ARGS[@]}" -o "$OUT/portable"
    dotnet "$OUT/portable/Smoke.dll"
    dotnet publish Smoke.csproj "${ARGS[@]}" -r "$RID" --self-contained -o "$OUT/self-contained"
    "$OUT/self-contained/Smoke"
else
    dotnet build Smoke.csproj "${ARGS[@]}" -c Release -r "$RID" -p:OutputPath="$OUT/app/"
    "$OUT/app/Smoke.app/Contents/MacOS/Smoke"
    dotnet build Smoke.csproj "${ARGS[@]}" -c Release -p:RuntimeIdentifiers='"osx-arm64;osx-x64"' \
        -p:BaseOutputPath="$OUT/universal/"
    "$OUT/universal/Release/$TFM/Smoke.app/Contents/MacOS/Smoke"
fi
