# `libvlc` for .NET

This repository is about presenting `libvlc` and its capabilities to .NET developers.
It also contains packaging tools and files for nuget packaging/deployment.

In other words : It's just the same thing as you'd download from VideoLAN's website, in a NuGet package,
that you can add in your .net project so that it gets copied into the output directory.

# What is libvlc?

`libvlc` is the multimedia framework powering the VLC applications. It is fully opensource, so other apps use it too.

**API documentation**: https://www.videolan.org/developers/vlc/doc/doxygen/html/group__libvlc.html

it contains all modules, data structures and functions documentation to understand how to use the `libvlc` C API.

The **source** is in the main VLC repository: https://github.com/videolan/vlc

`libvlc` is *modularized* into hundreds of plugins, which may be loaded at runtime. This architecture provides great flexibility to developers (both VLC devs and devs consuming the library). The unified, complete and (somewhat) high level `libvlc` C API allows a wide range of operations, such as:
- Network browsing for distant filesystems (SMB, FTP, SFTP, NFS...).
- HDMI passthrough for Audio HD codecs, like E-AC3, TrueHD or DTS-HD.
- Stream to distant renderers, like Chromecast.
- 360 video and 3D audio playback with viewpoint change.
- Support for Ambisonics audio and more than 8 audio channels.
- Subtitles size modification live.
- Hardware decoding and display on all platforms.
- DVD playback and menu navigation.

Full list of features can be found here: https://www.videolan.org/vlc/releases/3.0.0.html

Full directory tree overview of what's included (dlls, headers, lib files) in the nuget can be found at https://github.com/mfkl/libvlc-nuget/blob/master/tree.md

# How do I use this thing from .NET?

There are usually 2 ways to go about consuming C code from .NET:
- Using [C++/CX](https://docs.microsoft.com/en-us/cpp/cppcx/visual-c-language-reference-c-cx). This allows to author [Windows Runtime components](https://docs.microsoft.com/en-us/cpp/windows/windows-runtime-cpp-template-library-wrl) and it is Windows-specific. [VLC for UWP](https://code.videolan.org/videolan/vlc-winrt) currrently works this way using both [libvlcppcx](https://github.com/kakone/libVLCX) and [libvlcpp](https://code.videolan.org/videolan/libvlcpp).
- Using [P/Invoke](http://www.mono-project.com/docs/advanced/pinvoke/). If crossplatform is a focus, you should checkout [LibVLCSharp](https://github.com/mfkl/LibVLCSharp).

Versioning of the nuget packages naturally follow the libvlc versioning.

#### 3.0.0: https://github.com/videolan/vlc-3.0/releases/tag/3.0.0

## Windows x86/x64
```cmd
 dotnet add package VideoLAN.LibVLC.Windows --version 3.0.0-alpha2
```
https://www.nuget.org/packages/VideoLAN.LibVLC.Windows/

*Note: if you intend to use libvlc with UWP projects, you probably need to install the WindowsRT package instead because this build directly uses win32 APIs.*


To-do:
- Android
- iOS
- macOS
- WindowsRT x86/x64 (10)
- Linux

# How do I configure what gets copied to my output directory ?

Currently, you can customize two things during the build:
- Whether the library gets copied or not
- Where the library is placed in the output folder

## Enabling/Disabling a copy for a specific configuration

Suppose you have a custom build platform named `MyFancyBuildPlatformx64` instead of the default `x64`.

This package doesn't know if it should copy x86 or x64 libraries for that platform it doesn't know.
You have to tell msbuild explicitely.

In your csproj, you can define the `<CopyVlc64>` property.
(`<CopyVlc86>` is also available, as you guessed it, for x86)

Examples:

Adding x64 libraries for the `MyFancyBuildPlatformx64` platform:
```
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|MyFancyBuildPlatformx64'">
    <CopyVlc64>true</CopyVlc64>
  </PropertyGroup>
```

Don't copy x86 libraries for the AnyCPU builds:

```
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|AnyCPU'">
    <CopyVlc86>false</CopyVlc86>
  </PropertyGroup>
```

For the newer csproj format, you must place that before the `<PackageReference`
tag for this package.

## Specify the location where libvlc will be copied

The default locations are `libvlc/win-x64` and `libvlc/win-x86`

You can change that to your likings:

Example : send libvlc to `native/x86`/`native/x64`
```
  <PropertyGroup>
    <VlcLib64TargetDir>native/x64</VlcLib64TargetDir>
    <VlcLib86TargetDir>native/x86</VlcLib86TargetDir>
  </PropertyGroup>
```
