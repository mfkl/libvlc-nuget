#! /bin/bash

version=$1
echo "packaging version $version"

downloadUrlBinary="https://bintray.com/videolan/Android/download_file?file_path=org%2Fvideolan%2Fandroid%2Flibvlc-all%2F3.3.8%2Flibvlc-all-3.3.8.aar"
# downloadUrlArm8="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-arm64-v8a.apk"
# downloadUrlx86="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-x86.apk"
# downloadUrlx86_64="https://download.videolan.org/pub/videolan/vlc-android/$version/VLC-Android-$version-x86_64.apk"

sourceUrl="https://bintray.com/videolan/Android/download_file?file_path=org%2Fvideolan%2Fandroid%2Flibvlc-all%2F3.3.8%2Flibvlc-all-3.3.8-sources.jar"

packageName="VideoLAN.LibVLC.Android"
echo "package name $packageName"

# curl -Lsfo binary.7z $downloadUrlBinary --progress-bar --verbose

echo "downloading NuGet..."
# curl -Lsfo nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe

echo "unzipping libvlc.so ..."
7z e binary.7z jni/armeabi-v7a/libvlc.so -obuild/android-armv7 -aoa
7z e binary.7z jni/armeabi-v7a/libc++_shared.so -obuild/android-armv7 -aoa

7z e binary.7z jni/arm64-v8a/libvlc.so -obuild/android-armv8 -aoa
7z e binary.7z jni/arm64-v8a/libc++_shared.so -obuild/android-armv8 -aoa

7z e binary.7z jni/x86/libvlc.so -obuild/android-x86 -aoa
7z e binary.7z jni/x86/libc++_shared.so -obuild/android-x86 -aoa

7z e binary.7z jni/x86_64/libvlc.so -obuild/android-x86_64 -aoa
7z e binary.7z jni/x86_64/libc++_shared.so -obuild/android-x86_64 -aoa

touch build/android-armv7/libvlc.so
touch build/android-armv7/libc++_shared.so

touch build/android-armv8/libvlc.so
touch build/android-armv8/libc++_shared.so

touch build/android-x86/libvlc.so
touch build/android-x86/libc++_shared.so

touch build/android-x86_64/libvlc.so
touch build/android-x86_64/libc++_shared.so

# curl -Lsfo sources.zip $sourceUrl --progress-bar --verbose

# 7z e sources.zip org/videolan/libvlc/AWindow.java -obuild/toBuild -aoa
# 7z e sources.zip org/videolan/libvlc/interfaces/IVLCVout.java -obuild/toBuild -aoa
# 7z e sources.zip org/videolan/libvlc/util/AndroidUtil.java -obuild/toBuild -aoa
