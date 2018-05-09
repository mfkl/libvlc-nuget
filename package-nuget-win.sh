#! /bin/bash

version=$1
downloadUrlx86="https://get.videolan.org/vlc/$version/win32/vlc-$version-win32.7z"
downloadUrlx64="https://get.videolan.org/vlc/$version/win64/vlc-$version-win64.7z"

packageName="VideoLAN.LibVLC.Windows"

echo "downloading x86 binaries..." $downloadUrlx86
curl -Lsfo x86.7z $downloadUrlx86

echo "downloading x64 binaries..." $downloadUrlx64
curl -Lsfo x64.7z $downloadUrlx64

echo "downloading NuGet..."
curl -Lsfo nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
echo "unzipping vlc..."
7z x x86.7z -o./x86
7z x x64.7z -o./x64

echo "copying x86 dlls, libs and headers files..."
mkdir -p build/win7-x86/native/
cp -R ./x86/vlc-$version/{libvlc.dll,libvlccore.dll,hrtfs,locale,lua,plugins} build/win7-x86/native/
cp ./x86/vlc-$version/sdk/lib/{libvlc.lib,libvlccore.lib,vlc.lib,vlccore.lib} build/win7-x86/native/
cp -R ./x86/vlc-$version/sdk/include build/win7-x86/native/

echo "copying x64 dlls, libs and headers files..."
mkdir -p build/win7-x64/native/
cp -R ./x64/vlc-$version/{libvlc.dll,libvlccore.dll,hrtfs,locale,lua,plugins} build/win7-x64/native/
cp ./x64/vlc-$version/sdk/lib/{libvlc.lib,libvlccore.lib,vlc.lib,vlccore.lib} build/win7-x64/native/
cp -R ./x64/vlc-$version/sdk/include build/win7-x64/native/

echo "cleaning up..."
rm ./x86.7z
rm -rf ./x86
rm ./x64.7z
rm -rf ./x64

echo "packaging"

mono nuget.exe pack "$packageName".nuspec -Version "$version"

echo "done"
