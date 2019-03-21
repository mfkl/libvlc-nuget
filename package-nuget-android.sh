#! /bin/bash

version=$1
echo "packaging version $version"

downloadUrlArm7="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-armeabi-v7a.apk"
downloadUrlArm8="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-arm64-v8a.apk"
downloadUrlx86="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-x86.apk"
downloadUrlx86_64="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-x86_64.apk"

sourceUrl="https://github.com/videolan/vlc-android/archive/$version.zip"

packageName="VideoLAN.LibVLC.Android"
echo "package name $packageName"

# curl -Lsfo arm7.7z $downloadUrlArm7 --progress-bar --verbose
# curl -Lsfo arm8.7z $downloadUrlArm8 --progress-bar --verbose
# curl -Lsfo x86.7z $downloadUrlx86 --progress-bar --verbose
# curl -Lsfo x86_64.7z $downloadUrlx86_64 --progress-bar --verbose

echo "downloading NuGet..."
# curl -Lsfo nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe

echo "unzipping libvlc.so ..."
# 7z e arm7.7z lib/armeabi-v7a/libvlc.so -obuild/android-armv7
# 7z e arm8.7z lib/arm64-v8a/libvlc.so -obuild/android-armv8
# 7z e x86.7z lib/x86/libvlc.so -obuild/android-x86
# 7z e x86_64.7z lib/x86_64/libvlc.so -obuild/android-x86_64

#curl -Lsfo sources.zip $sourceUrl --progress-bar --verbose

7z e sources.zip vlc-android-$version/libvlc/src/org/videolan/libvlc/AWindow.java -obuild/toBuild
7z e sources.zip vlc-android-$version/libvlc/src/org/videolan/libvlc/IVLCVout.java -obuild/toBuild
7z e sources.zip vlc-android-$version/libvlc/src/org/videolan/libvlc/util/AndroidUtil.java -obuild/toBuild

#mono nuget.exe pack "$packageName".nuspec -Version "$version"