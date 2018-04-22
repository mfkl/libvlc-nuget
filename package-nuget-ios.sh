#! /bin/bash
# git checkout tags/3.0.0
# build with xcode
# rename DynamicMobileVLCKit.Framework/DynamicMobileVLCKit to libvlc.dylib
nuget pack "VideoLAN.LibVLC.iOS.nuspec" -Version "$version"