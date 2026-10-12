#!/usr/bin/env bash
# Repackages the official VLC macOS releases (arm64 and intel64) into the
# VideoLAN.LibVLC.Mac.GPL and LGPL VideoLAN.LibVLC.Mac packages, with one
# runtime tree per architecture.
set -euo pipefail

version=${1:?"Usage: $0 <libvlc version>"}
downloadUrl="https://download.videolan.org/pub/videolan/vlc/$version/macosx"
packageName="VideoLAN.LibVLC.Mac"
sevenZip=$(command -v 7zz || command -v 7z) || { echo "ERROR: 7-Zip is required" >&2; exit 1; }

# Same GPL modules as the Windows LGPL package. macOS plugins are not grouped
# in folders, so the Windows "control" and "gui" folders are listed by name.
# libx26410b_plugin is x264 built for 10-bit output.
gpl_plugins=(
  libdvdnav_plugin libdvdread_plugin
  libmad_plugin libmono_plugin libsamplerate_plugin
  libaribsub_plugin libfaad_plugin libt140_plugin libx264_plugin libx26410b_plugin libx265_plugin
  libdummy_plugin libgestures_plugin libhotkeys_plugin libmotion_plugin libnetsync_plugin liboldrc_plugin
  libmpc_plugin libreal_plugin libsid_plugin
  libmacosx_plugin libncurses_plugin
  libfile_logger_plugin
  libaudioscrobbler_plugin libexport_plugin liblogger_plugin libstats_plugin libvod_rtsp_plugin
  libpacketizer_a52_plugin
  libmediadirs_plugin libpodcast_plugin libsap_plugin
  libstream_out_cycle_plugin libstream_out_rtp_plugin
  libpostproc_plugin librotate_plugin
)

# Plugins that need frameworks bundled in VLC.app and cannot load elsewhere.
app_plugins=(libmacosx_plugin libosx_notifications_plugin)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for arch in arm64 intel64; do
  case $arch in
    arm64) rid=osx-arm64 ;;
    intel64) rid=osx-x64 ;;
  esac
  dmg="vlc-$version-$arch.dmg"
  echo "[$rid] Downloading $downloadUrl/$dmg"
  curl -Lsfo "$work/$dmg" "$downloadUrl/$dmg"
  expected=$(curl -Lsf "$downloadUrl/$dmg.sha256" | cut -d' ' -f1)
  actual=$(sha256sum "$work/$dmg" | cut -d' ' -f1)
  [ "$expected" = "$actual" ] || { echo "ERROR: $dmg checksum mismatch" >&2; exit 1; }

  "$sevenZip" x -y -sns- -o"$work/$arch" "$work/$dmg" "VLC media player/VLC.app/Contents/MacOS/*" > /dev/null
  app="$work/$arch/VLC media player/VLC.app/Contents/MacOS"

  # VLC 3 looks for plugins and data in <libvlccore directory>/vlc.
  out="build/macos/$rid/lib"
  rm -rf "build/macos/$rid"
  mkdir -p "$out/vlc/share"
  cp "$app"/lib/libvlc.[0-9]*.dylib "$out/libvlc.dylib"
  cp "$app"/lib/libvlccore.[0-9]*.dylib "$out/libvlccore.dylib"
  cp -R "$app/plugins" "$out/vlc/plugins"
  cp -R "$app/share/lua" "$app/share/hrtfs" "$out/vlc/share/"
  # The plugin cache would still list the removed plugins.
  rm -f "$out/vlc/plugins/plugins.dat"
  for plugin in "${app_plugins[@]}"; do
    rm -f "$out/vlc/plugins/$plugin.dylib"
  done
  echo "[$rid] $(find "$out/vlc/plugins" -name '*.dylib' | wc -l) plugins"
done

echo "Packing $packageName.GPL"
dotnet pack "$packageName.csproj" -p:NuspecFile="$packageName.GPL.nuspec" -o .

for rid in osx-arm64 osx-x64; do
  for plugin in "${gpl_plugins[@]}"; do
    rm -f "build/macos/$rid/lib/vlc/plugins/$plugin.dylib"
  done
  echo "[$rid] $(find "build/macos/$rid/lib/vlc/plugins" -name '*.dylib' | wc -l) LGPL plugins"
done

echo "Packing $packageName"
dotnet pack "$packageName.csproj" -o .
ls -la ./*.nupkg
