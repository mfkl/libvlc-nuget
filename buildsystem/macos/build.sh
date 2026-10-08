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
XCODE_VERSION=$(xcodebuild -version)
[[ ${XCODE_VERSION%%$'\n'*} == "Xcode $EXPECTED_XCODE" ]] || {
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
# Stage libvlc, libvlccore, every built plugin and VLC's data files.
INSTALL="$SOURCE/nuget-build/vlc-macosx-$ARCH"
OUT="$ROOT/.macos-work/staging/$RID"
rm -rf "$OUT"
mkdir -p "$OUT/lib/vlc" "$OUT/licenses"
cp -L "$INSTALL/lib/libvlc.dylib" "$INSTALL/lib/libvlccore.dylib" "$OUT/lib/"
rsync -a --prune-empty-dirs --include='*/' --include='*_plugin.dylib' --exclude='*' \
    "$INSTALL/lib/vlc/plugins/" "$OUT/lib/vlc/plugins/"
if [[ -d "$INSTALL/share/vlc" ]]; then cp -RL "$INSTALL/share/vlc" "$OUT/lib/vlc/share"; fi

# Replace absolute build paths with paths relative to each library, then re-sign.
while IFS= read -r lib; do
    id=$(otool -D "$lib" | tail -n +2)
    to_lib=$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]) + "/")' "$OUT/lib" "$(dirname "$lib")")
    to_lib=${to_lib#./}
    args=(-id "@rpath/$(basename "$lib")")
    while IFS= read -r dep; do
        case "$dep" in
            "$id"|/usr/lib/*|/System/*) ;;
            */libvlccore*.dylib) args+=(-change "$dep" "@loader_path/${to_lib}libvlccore.dylib") ;;
            */libvlc.*dylib) args+=(-change "$dep" "@loader_path/${to_lib}libvlc.dylib") ;;
            *) echo "Unexpected dependency $dep in $lib" >&2; exit 1 ;;
        esac
    done < <(otool -L "$lib" | tail -n +2 | awk '{print $1}')
    while IFS= read -r rpath; do
        args+=(-delete_rpath "$rpath")
    done < <(otool -l "$lib" | awk '/cmd LC_RPATH/ { getline; getline; print $2 }')
    install_name_tool "${args[@]}" "$lib"
    codesign --force --sign - "$lib"
done < <(find "$OUT/lib" -name '*.dylib')

shopt -s nullglob
cp "$SOURCE"/{COPYING,COPYING.LIB,AUTHORS,THANKS} "$OUT/licenses/"
for package in "$SOURCE"/contrib/contrib-*/*/; do
    notices=("$package"{COPYING,LICENSE,LICENCE,COPYRIGHT,Copyright,copyright,NOTICE}*)
    if (( ${#notices[@]} )); then
        mkdir -p "$OUT/licenses/$(basename "$package")"
        cp "${notices[@]}" "$OUT/licenses/$(basename "$package")/"
    fi
done

tar -czf "$ROOT/.macos-work/$RID.tar.gz" -C "$ROOT/.macos-work/staging" "$RID"
