#! /bin/bash

version=$1
downloadUrl="http://download.videolan.org/pub/videolan/vlc/$version/macosx/vlc-$version.dmg"

packageName="VideoLAN.LibVLC.Mac"

echo "downloading binaries..." $downloadUrl
curl -Lsfo mac.dmg $downloadUrl

echo "downloading NuGet..."
curl -Lsfo nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
echo "unzipping vlc..."
7z x mac.dmg -o./mac 
7z x mac/4.hfs

echo "copying dlls, libs and headers files..."
mkdir -p build/osx-x64/
cp -R VLC\ media\ player/VLC.app/Contents/MacOS/{include,lib,plugins,share} build/osx-x64/

echo "cleaning up..."
rm -rf ./mac ./VLC\ media\ player ./mac.dmg

echo "packaging"

mono nuget.exe pack "$packageName".nuspec -Version "$version"

echo "done"