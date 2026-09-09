#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
RID=${1:?Usage: build.sh osx-x64|osx-arm64}
case "$RID" in
    osx-x64) ARCH=x86_64 ;;
    osx-arm64) ARCH=arm64 ;;
    *) echo "Unsupported RID: $RID" >&2; exit 1 ;;
esac
[[ $(uname -s) == Darwin && $(uname -m) == "$ARCH" ]] || {
    echo "Build $RID on a native $ARCH Mac" >&2; exit 1;
}
read_version() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$ROOT/buildsystem/macos/versions.json" "$1"; }
TAG=$(read_version vlc_tag)
COMMIT=$(read_version vlc_commit)
EXPECTED_XCODE=$(read_version xcode)
[[ $(xcodebuild -version | head -n 1) == "Xcode $EXPECTED_XCODE" ]] || {
    echo "Select Xcode $EXPECTED_XCODE before building" >&2; exit 1;
}
WORK="$ROOT/.macos-work/$RID"
SOURCE="$WORK/vlc"
mkdir -p "$WORK" "$ROOT/.macos-work/logs/$RID"
exec > >(tee "$ROOT/.macos-work/logs/$RID/build.log") 2>&1
if [[ ! -d "$SOURCE" ]]; then
    git clone --depth 1 --branch "$TAG" https://code.videolan.org/videolan/vlc.git "$SOURCE"
fi
[[ $(git -C "$SOURCE" rev-parse HEAD) == "$COMMIT" ]] || { echo 'Unexpected VLC commit' >&2; exit 1; }
for patch_name in vlc-macos-linker.patch vlc-macos-tools.patch; do
    PATCH="$ROOT/buildsystem/macos/$patch_name"
    if git -C "$SOURCE" apply --check "$PATCH"; then
        git -C "$SOURCE" apply "$PATCH"
    else
        git -C "$SOURCE" apply --reverse --check "$PATCH"
    fi
done
if [[ ! -f "$SOURCE/extras/package/apple/build.conf.upstream" ]]; then
    cp "$SOURCE/extras/package/apple/build.conf" "$SOURCE/extras/package/apple/build.conf.upstream"
fi
cp "$ROOT/buildsystem/macos/build.conf" "$SOURCE/extras/package/apple/build.conf"
mkdir -p "$SOURCE/nuget-build"
# Do not let Homebrew pkg-config packages or caller compiler flags contaminate
# the LGPL contrib build. Apple's script supplies compiler/SDK flags itself.
unset PKG_CONFIG_PATH CFLAGS CXXFLAGS CPPFLAGS LDFLAGS SDKROOT
export PKG_CONFIG_LIBDIR=""
export LC_ALL=C
export MAKE=make
cd "$SOURCE/nuget-build"
bash ../extras/package/apple/build.sh --arch="$ARCH" --sdk=macosx --enable-shared --disable-debug -j"$(sysctl -n hw.ncpu)"
python3 "$ROOT/buildsystem/macos/stage.py" "$SOURCE" "$RID" "$ROOT/.macos-work/staging/$RID"
python3 "$ROOT/buildsystem/macos/verify.py" "$ROOT/.macos-work/staging/$RID" "$RID"
# Source delivery includes upstream sources, contrib archives/patches and the
# exact packaging scripts. Keep this separate from the runtime NuGet package.
mkdir -p "$ROOT/.macos-work/sources/$RID"
git -C "$SOURCE" archive --format=tar HEAD | gzip > "$ROOT/.macos-work/sources/$RID/vlc-$TAG.tar.gz"
tar -czf "$ROOT/.macos-work/sources/$RID/contrib-sources.tar.gz" -C "$SOURCE/contrib" tarballs src
tar -czf "$ROOT/.macos-work/sources/$RID/packaging-scripts.tar.gz" -C "$ROOT" buildsystem/macos build/VideoLAN.LibVLC.Mac.targets VideoLAN.LibVLC.Mac.nuspec
tar -czf "$ROOT/.macos-work/$RID.tar.gz" -C "$ROOT/.macos-work/staging" "$RID"
