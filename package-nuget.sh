#! /bin/bash

downloadUrl=$1
version=$(date +%Y.%m.%d)
package="VideoLAN.LibVLC.Win.x64"

echo "downloading " $downloadUrl
curl -Lsfo x64.7z $downloadUrl
echo "downloading NuGet..."
curl -Lsfo nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
echo "unzipping vlc win x64..."
7z x ./x64.7z -o./x64-extract
echo "extracting dlls, libs and headers files..."
mkdir -p build/win7-x64/native/
cp ./x64-extract/vlc-3.0.0-git/{libvlc.dll,libvlccore.dll} build/win7-x64/native/
cp ./x64-extract/vlc-3.0.0-git/sdk/lib/{libvlc.lib,libvlccore.lib,vlc.lib,vlccore.lib} build/win7-x64/native/
cp -R ./x64-extract/vlc-3.0.0-git/plugins build/win7-x64/native/
cp -R ./x64-extract/vlc-3.0.0-git/sdk/include build/win7-x64/native/

rm ./x64.7z
rm -rf ./x64-extract
echo "done"

mono nuget.exe pack -Version "$version"