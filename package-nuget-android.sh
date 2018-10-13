#! /bin/bash

version=$1
echo "packaging version $version"

downloadUrlArm7="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-ARMv7.apk"
downloadUrlArm8="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-ARMv8.apk"
downloadUrlx86="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-x86.apk"
downloadUrlx86_64="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-x86_64.apk"

packageName="VideoLAN.LibVLC.Android"
echo "package name $packageName"

curl -Lsfo arm7.7z $downloadUrlArm7 --progress-bar --verbose
curl -Lsfo arm8.7z $downloadUrlArm8 --progress-bar --verbose
curl -Lsfo x86.7z $downloadUrlx86 --progress-bar --verbose
curl -Lsfo x86_64.7z $downloadUrlx86_64 --progress-bar --verbose

echo "downloading NuGet..."
curl -Lsfo nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe

echo "unzipping vlc..."
7z x arm7.7z -o./arm7
7z x arm8.7z -o./arm8
7z x x86.7z -o./x86
7z x x86_64.7z -o./x86_64

echo "copying x86 dlls, libs and headers files..."

mkdir -p build/android-armv7/
cp ./arm7/lib/armeabi-v7a/libvlcjni.so build/android-armv7/
mv build/android-armv7/libvlcjni.so build/android-armv7/libvlc.so

mkdir -p build/android-armv8/
cp ./arm8/lib/arm64-v8a/libvlcjni.so build/android-armv8/
mv build/android-armv8/libvlcjni.so build/android-armv8/libvlc.so

mkdir -p build/android-x86/
cp ./x86/lib/x86/libvlcjni.so build/android-x86/
mv build/android-x86/libvlcjni.so build/android-x86/libvlc.so

mkdir -p build/android-x86_64/
cp ./x86_64/lib/x86_64/libvlcjni.so build/android-x86_64/
mv build/android-x86_64/libvlcjni.so build/android-x86_64/libvlc.so

echo "done"

mono nuget.exe pack "$packageName".nuspec -Version "$version"