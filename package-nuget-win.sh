#!/usr/bin/env bash
set -e

version=${1:?"Usage: $0 <libvlc version>"}
downloadUrlx86="https://get.videolan.org/vlc/$version/win32/vlc-$version-win32.7z"
downloadUrlx64="https://get.videolan.org/vlc/$version/win64/vlc-$version-win64.7z"
downloadUrlArm64="https://get.videolan.org/vlc/$version/winarm64/vlc-$version-winarm64.7z"

packageName="VideoLAN.LibVLC.Windows"
packageNameGPL="VideoLAN.LibVLC.Windows.GPL"

x86PluginsLocation="build/win7-x86/native/plugins"
x64PluginsLocation="build/win7-x64/native/plugins"
arm64PluginsLocation="build/win-arm64/native/plugins"

# GPL plugin list
gpl_plugins=(
  "access/libaccess_realrtsp_plugin.dll"
  "access/libdvdnav_plugin.dll"
  "access/libdvdread_plugin.dll"
  "access/libvnc_plugin.dll"
  "access/libdshow_plugin.dll"
  "audio_filter/libmad_plugin.dll"
  "audio_filter/libmono_plugin.dll"
  "audio_filter/libsamplerate_plugin.dll"
  "codec/liba52_plugin.dll"
  "codec/libaribsub_plugin.dll"
  "codec/libdca_plugin.dll"
  "codec/libfaad_plugin.dll"
  "codec/liblibmpeg2_plugin.dll"
  "codec/libt140_plugin.dll"
  "codec/libx264_plugin.dll"
  "codec/libx265_plugin.dll"
  "control"
  "demux/libmpc_plugin.dll"
  "demux/libreal_plugin.dll"
  "demux/libsid_plugin.dll"
  "gui"
  "logger/libfile_logger_plugin.dll"
  "misc/libaudioscrobbler_plugin.dll"
  "misc/libexport_plugin.dll"
  "misc/liblogger_plugin.dll"
  "misc/libstats_plugin.dll"
  "misc/libvod_rtsp_plugin.dll"
  "packetizer/libpacketizer_a52_plugin.dll"
  "services_discovery/libmediadirs_plugin.dll"
  "services_discovery/libpodcast_plugin.dll"
  "services_discovery/libsap_plugin.dll"
  "stream_out/libstream_out_cycle_plugin.dll"
  "stream_out/libstream_out_rtp_plugin.dll"
  "video_filter/libpostproc_plugin.dll"
  "video_filter/librotate_plugin.dll"
)

echo "=========================================="
echo "LibVLC Windows NuGet packaging v$version"
echo "=========================================="

# --- Download VLC binaries ---

echo ""
echo "[1/8] Downloading VLC binaries..."
echo "  x86:  $downloadUrlx86"
curl -Lsfo x86.7z "$downloadUrlx86"
echo "  x86: downloaded ($(stat -c%s x86.7z 2>/dev/null || stat -f%z x86.7z) bytes)"

echo "  x64:  $downloadUrlx64"
curl -Lsfo x64.7z "$downloadUrlx64"
echo "  x64: downloaded ($(stat -c%s x64.7z 2>/dev/null || stat -f%z x64.7z) bytes)"

echo "  arm64:  $downloadUrlArm64"
curl -Lsfo arm64.7z "$downloadUrlArm64"
echo "  arm64: downloaded ($(stat -c%s arm64.7z 2>/dev/null || stat -f%z arm64.7z) bytes)"

if [ ! -f "nuget.exe" ]; then
  echo "  nuget.exe not found, downloading..."
  curl -Lsfo nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
fi

# --- Extract archives ---

echo ""
echo "[2/8] Extracting archives..."
echo "  extracting x86..."
7z x x86.7z -o./x86
if [ ! -d "./x86/vlc-$version" ]; then
  echo "ERROR: expected directory ./x86/vlc-$version not found after extraction"
  exit 1
fi

echo "  extracting x64..."
7z x x64.7z -o./x64
if [ ! -d "./x64/vlc-$version" ]; then
  echo "ERROR: expected directory ./x64/vlc-$version not found after extraction"
  exit 1
fi

echo "  extracting arm64..."
7z x arm64.7z -o./arm64
if [ ! -d "./arm64/vlc-$version" ]; then
  echo "ERROR: expected directory ./arm64/vlc-$version not found after extraction"
  exit 1
fi

# --- Prepare architectures ---

echo ""
echo "[3/8] Preparing x86..."
rm -rf build/win7-x86/native/
mkdir -p build/win7-x86/native/
cp -R ./x86/vlc-$version/{libvlc.dll,libvlccore.dll,hrtfs,lua,plugins} build/win7-x86/native/
cp ./x86/vlc-$version/sdk/lib/{libvlc.lib,libvlccore.lib,vlc.lib,vlccore.lib} build/win7-x86/native/
cp -R ./x86/vlc-$version/sdk/include build/win7-x86/native/
echo "  x86 ready: $(find build/win7-x86/native -type f | wc -l) files"

echo ""
echo "[4/8] Preparing x64..."
rm -rf build/win7-x64/native/
mkdir -p build/win7-x64/native/
cp -R ./x64/vlc-$version/{libvlc.dll,libvlccore.dll,hrtfs,lua,plugins} build/win7-x64/native/
cp ./x64/vlc-$version/sdk/lib/{libvlc.lib,libvlccore.lib,vlc.lib,vlccore.lib} build/win7-x64/native/
cp -R ./x64/vlc-$version/sdk/include build/win7-x64/native/
echo "  x64 ready: $(find build/win7-x64/native -type f | wc -l) files"

echo ""
echo "[5/8] Preparing arm64..."
rm -rf build/win-arm64/native/
mkdir -p build/win-arm64/native/
cp -R ./arm64/vlc-$version/{libvlc.dll,libvlccore.dll,hrtfs,lua,plugins} build/win-arm64/native/
cp ./arm64/vlc-$version/sdk/lib/{libvlc.lib,libvlccore.lib,vlc.lib,vlccore.lib} build/win-arm64/native/
cp -R ./arm64/vlc-$version/sdk/include build/win-arm64/native/
echo "  arm64 ready: $(find build/win-arm64/native -type f | wc -l) files"

# --- Pack GPL NuGet ---

echo ""
echo "[6/8] Packaging GPL NuGet ($packageNameGPL v$version)..."
mono nuget.exe pack "$packageNameGPL".nuspec -Version "$version"
echo "  GPL package created"

# --- Remove GPL plugins ---

echo ""
echo "[7/8] Removing GPL plugins..."
for file in "${gpl_plugins[@]}"; do
  for loc in "$x86PluginsLocation" "$x64PluginsLocation" "$arm64PluginsLocation"; do
    if [ -e "$loc/$file" ]; then
      echo "  removing $loc/$file"
      rm -rf "$loc/$file"
    fi
  done
done
echo "  GPL plugins removed from all architectures"

# --- Pack LGPL NuGet ---

echo ""
echo "[8/8] Packaging LGPL NuGet ($packageName v$version)..."
mono nuget.exe pack "$packageName".nuspec -Version "$version"
echo "  LGPL package created"

# --- Cleanup ---

echo ""
echo "Cleaning up..."
rm -f ./x86.7z ./x64.7z ./arm64.7z
rm -rf ./x86 ./x64 ./arm64

echo ""
echo "Done. Generated packages:"
ls -la ./*.nupkg
