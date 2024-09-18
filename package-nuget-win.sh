#!/usr/bin/env bash
set -e

version=${1:?"Usage: $0 <libvlc version>"}
downloadUrlx86="https://get.videolan.org/vlc/$version/win32/vlc-$version-win32.7z"
downloadUrlx64="https://get.videolan.org/vlc/$version/win64/vlc-$version-win64.7z"

packageName="VideoLAN.LibVLC.Windows"
packageNameGPL="VideoLAN.LibVLC.Windows.GPL"

x86PluginsLocation="build/win7-x86/native/plugins"
x64PluginsLocation="build/win7-x64/native/plugins"

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

# echo "downloading x86 binaries..." $downloadUrlx86
curl -Lsfo x86.7z $downloadUrlx86

# echo "downloading x64 binaries..." $downloadUrlx64
curl -Lsfo x64.7z $downloadUrlx64

if [ ! -f "nuget.exe" ]; then
  echo "downloading NuGet..."
  curl -Lsfo nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
fi

echo "unzipping vlc..."
7z x x86.7z -o./x86
7z x x64.7z -o./x64

echo "copying x86 dlls, libs and headers files..."
mkdir -p build/win7-x86/native/
cp -R ./x86/vlc-$version/{libvlc.dll,libvlccore.dll,hrtfs,lua,plugins} build/win7-x86/native/
cp ./x86/vlc-$version/sdk/lib/{libvlc.lib,libvlccore.lib,vlc.lib,vlccore.lib} build/win7-x86/native/
cp -R ./x86/vlc-$version/sdk/include build/win7-x86/native/

echo "copying x64 dlls, libs and headers files..."
mkdir -p build/win7-x64/native/
cp -R ./x64/vlc-$version/{libvlc.dll,libvlccore.dll,hrtfs,lua,plugins} build/win7-x64/native/
cp ./x64/vlc-$version/sdk/lib/{libvlc.lib,libvlccore.lib,vlc.lib,vlccore.lib} build/win7-x64/native/
cp -R ./x64/vlc-$version/sdk/include build/win7-x64/native/

echo "packaging GPL version..."

mono nuget.exe pack "$packageNameGPL".nuspec -Version "$version"

echo "removing GPL plugins from x86..."

# remove x86 GPL plugins
for file in "${gpl_plugins[@]}"; do
  rm -rf "$x86PluginsLocation/$file"
done

echo "removing GPL plugins from x64..."

# remove x64 GPL plugins
for file in "${gpl_plugins[@]}"; do
  rm -rf "$x64PluginsLocation/$file"
done

echo "packaging LGPL version..."

mono nuget.exe pack "$packageName".nuspec -Version "$version"

echo "cleaning up..."
rm ./x86.7z
rm -rf ./x86
rm ./x64.7z
rm -rf ./x64

echo "done"
