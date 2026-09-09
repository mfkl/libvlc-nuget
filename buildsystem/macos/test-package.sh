#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Test command failed at line $LINENO: $BASH_COMMAND" >&2' ERR
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
RID=${1:?Usage: test-package.sh osx-x64|osx-arm64 net8.0|net8.0-macos}
TFM=${2:?Specify net8.0 or net8.0-macos}
case "$RID" in osx-x64) OTHER=osx-arm64;; osx-arm64) OTHER=osx-x64;; *) exit 1;; esac
case "$TFM" in
    net8.0) ;;
    net8.0-macos) cd "$ROOT/buildsystem/macos/apple";;
    *) echo "Unsupported test target: $TFM" >&2; exit 1;;
esac
read_version() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$ROOT/buildsystem/macos/versions.json" "$1"; }
TESTROOT="$ROOT/.macos-work/consumer-$RID-$TFM"
mkdir -p "$TESTROOT" "$TESTROOT/fixtures"
exec > >(tee "$TESTROOT/test.log") 2>&1
cp "$ROOT/buildsystem/macos/smoke/"* "$TESTROOT/"
export NUGET_PACKAGES="$TESTROOT/packages"
export SMOKE_EXPECTED_RID="$RID" SMOKE_EXPECTED_TFM="$TFM"
unset VLC_PLUGIN_PATH VLC_DATA_PATH DYLD_LIBRARY_PATH DYLD_FALLBACK_LIBRARY_PATH
# Locally generated, deterministic synthetic media; no external media downloads.
# FFmpeg is a test-only tool, never a packaging input.
ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc2=size=64x64:rate=10 \
    -f lavfi -i sine=frequency=440:sample_rate=48000 -t 2 -c:v mpeg4 -c:a aac "$TESTROOT/fixtures/sample.mp4"
ffmpeg -hide_banner -loglevel error -i "$TESTROOT/fixtures/sample.mp4" -c copy "$TESTROOT/fixtures/sample.mkv"
rm -f "$TESTROOT/port"
python3 -u "$ROOT/buildsystem/macos/test-server.py" "$TESTROOT/fixtures" "$TESTROOT/port" > "$TESTROOT/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
for attempt in {1..300}; do
    [[ -s "$TESTROOT/port" ]] && break
    kill -0 "$SERVER_PID" 2>/dev/null || break
    sleep 0.1
done
if [[ ! -s "$TESTROOT/port" ]]; then
    echo "Fixture server failed to start within 30 seconds" >&2
    cat "$TESTROOT/server.log" >&2
    exit 1
fi
PORT=$(cat "$TESTROOT/port")
curl --fail --silent --show-error --max-time 5 "http://127.0.0.1:$PORT/sample.mp4" -o /dev/null
PROPS=(-p:TargetFramework="$TFM" -p:NativePackageVersion="$(read_version package_version)" -p:LoaderPackageVersion="$(read_version libvlcsharp_package_version)")
python3 - "$TESTROOT/NuGet.Config" "$ROOT/.macos-work/packages" <<'PY'
import sys, xml.etree.ElementTree as ET
config = ET.Element('configuration')
sources = ET.SubElement(config, 'packageSources')
ET.SubElement(sources, 'clear')
ET.SubElement(sources, 'add', key='preview', value=sys.argv[2])
ET.SubElement(sources, 'add', key='nuget.org', value='https://api.nuget.org/v3/index.json')
ET.ElementTree(config).write(sys.argv[1], encoding='utf-8', xml_declaration=True)
PY
PROPS+=(-p:RestoreConfigFile="$TESTROOT/NuGet.Config")
play() {
    (cd /tmp && "$@" \
        "file://$TESTROOT/fixtures/sample.mp4" "file://$TESTROOT/fixtures/sample.mkv" \
        "http://127.0.0.1:$PORT/sample.mp4")
}
if [[ "$TFM" == net8.0-macos ]]; then
    # A single explicit RID prevents the Apple SDK from producing a universal app.
    # Execute the actual SDK-generated apphost for both build and publish output.
    for mode in build publish; do
        dotnet "$mode" "$TESTROOT/Smoke.csproj" "${PROPS[@]}" -c Release \
            -r "$RID" --self-contained true -o "$TESTROOT/$mode" -bl:"$TESTROOT/$mode.binlog"
        APP="$TESTROOT/$mode/Smoke.app"
        test -x "$APP/Contents/MacOS/Smoke"
        RUNTIME="$APP/Contents/MonoBundle/libvlc"
        test -f "$RUNTIME/$RID/lib/libvlc.dylib"
        test ! -d "$RUNTIME/$OTHER"
        python3 "$ROOT/buildsystem/macos/verify.py" "$RUNTIME/$RID" "$RID"
        codesign --verify --deep --strict "$APP"
        mv "$TESTROOT/$mode" "$TESTROOT/relocated-$mode"
        play "$TESTROOT/relocated-$mode/Smoke.app/Contents/MacOS/Smoke"
    done
    exit 0
fi
dotnet restore "$TESTROOT/Smoke.csproj" "${PROPS[@]}"
dotnet build "$TESTROOT/Smoke.csproj" --no-restore "${PROPS[@]}" -o "$TESTROOT/portable" -bl:"$TESTROOT/portable.binlog"
for mode in portable framework self-contained; do
    if [[ "$mode" != portable ]]; then
        SELF=false; [[ "$mode" == self-contained ]] && SELF=true
        dotnet publish "$TESTROOT/Smoke.csproj" "${PROPS[@]}" -r "$RID" --self-contained "$SELF" -o "$TESTROOT/$mode" -bl:"$TESTROOT/$mode.binlog"
    fi
    test -f "$TESTROOT/$mode/libvlc/$RID/lib/libvlc.dylib"
    if [[ "$mode" == portable ]]; then
        test -f "$TESTROOT/$mode/libvlc/$OTHER/lib/libvlc.dylib"
    else
        test ! -d "$TESTROOT/$mode/libvlc/$OTHER"
    fi
    python3 "$ROOT/buildsystem/macos/verify.py" "$TESTROOT/$mode/libvlc/$RID" "$RID"
    mv "$TESTROOT/$mode" "$TESTROOT/relocated-$mode"
    COMMAND=(dotnet "$TESTROOT/relocated-$mode/Smoke.dll")
    if [[ "$mode" == self-contained ]]; then COMMAND=("$TESTROOT/relocated-$mode/Smoke"); fi
    play "${COMMAND[@]}"
done
# Check cross-publishing selection, even though this runner cannot execute it.
dotnet publish "$TESTROOT/Smoke.csproj" "${PROPS[@]}" -r "$OTHER" --self-contained false -o "$TESTROOT/cross" -bl:"$TESTROOT/cross.binlog"
test -f "$TESTROOT/cross/libvlc/$OTHER/lib/libvlc.dylib"
test ! -d "$TESTROOT/cross/libvlc/$RID"
