#! /bin/bash

version="3.6.5" # vlc-android tag
echo "packaging version $version"

downloadUrlArm7="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-armeabi-v7a.apk"
downloadUrlArm8="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-arm64-v8a.apk"
downloadUrlx86="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-x86.apk"
downloadUrlx86_64="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-x86_64.apk"

sourceUrl="https://github.com/videolan/vlc-android/archive/$version.zip"

packageName="VideoLAN.LibVLC.Android"
echo "package name $packageName"

# curl -Lsfo VLC-Android-$version-armeabi-v7a.apk $downloadUrlArm7 --progress-bar --verbose
# curl -Lsfo VLC-Android-$version-arm64-v8a.apk $downloadUrlArm8 --progress-bar --verbose
# curl -Lsfo VLC-Android-$version-x86.apk $downloadUrlx86 --progress-bar --verbose
# curl -Lsfo VLC-Android-$version-x86_64.apk $downloadUrlx86_64 --progress-bar --verbose

echo "downloading NuGet..."
# curl -Lsfo nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe

echo "unzipping libvlc.so and libc++_shared.so..."
7z e VLC-Android-$version-armeabi-v7a.apk lib/armeabi-v7a/libvlc.so lib/armeabi-v7a/libc++_shared.so -obuild/android-armv7 -y
7z e VLC-Android-$version-arm64-v8a.apk lib/arm64-v8a/libvlc.so lib/arm64-v8a/libc++_shared.so -obuild/android-armv8 -y
7z e VLC-Android-$version-x86.apk lib/x86/libvlc.so lib/x86/libc++_shared.so -obuild/android-x86 -y
7z e VLC-Android-$version-x86_64.apk lib/x86_64/libvlc.so lib/x86_64/libc++_shared.so -obuild/android-x86_64 -y

# workaround a 7zip/nuget bug (datetime 0)
touch build/android-armv7/libvlc.so
touch build/android-armv7/libc++_shared.so
touch build/android-armv8/libvlc.so
touch build/android-armv8/libc++_shared.so
touch build/android-x86/libvlc.so
touch build/android-x86/libc++_shared.so
touch build/android-x86_64/libvlc.so
touch build/android-x86_64/libc++_shared.so

# curl -Lsfo sources.zip $sourceUrl --progress-bar --verbose

# 7z e sources.zip vlc-android-$version/libvlc/src/org/videolan/libvlc/AWindow.java -obuild/toBuild
# 7z e sources.zip vlc-android-$version/libvlc/src/org/videolan/libvlc/IVLCVout.java -obuild/toBuild
# 7z e sources.zip vlc-android-$version/libvlc/src/org/videolan/libvlc/util/AndroidUtil.java -obuild/toBuild

#mono nuget.exe pack "$packageName".nuspec -Version "$version"