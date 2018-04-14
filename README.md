# `libvlc` for .NET

This repository is about presenting `libvlc` and its capabilities to .NET developers.
It also contains packaging tools and files for nuget packaging/deployment.

In other words: It's just the same thing as if you had downloaded the files from VideoLAN's website, in a NuGet package,
that you can add in your .NET project so that it gets copied into the output directory.

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
Minimum OS version supported by LibVLC 3.0:
- Windows XP
- macOS 10.7
- iOS 7
- Android 2.3

## Windows (x86/x64)
```cmd
 dotnet add package VideoLAN.LibVLC.Windows --version 3.0.0-alpha2
```
https://www.nuget.org/packages/VideoLAN.LibVLC.Windows/

#### Supported CPU architectures:
- x86
- x64

*Note: if you intend to use libvlc with UWP projects, you probably need to install the WindowsRT package instead because this build directly uses win32 APIs.*

## Android
```cmd
dotnet add package VideoLAN.LibVLC.Android
```
https://www.nuget.org/packages/VideoLAN.LibVLC.Android/

#### Supported CPU architectures:
- armeabi-v7a
- arm64-v8a
- x86
- x86_64

To-do:
- iOS
- macOS
- WindowsRT x86/x64 (10)
- Linux
- Tizen
- WebAssembly

# How do I configure what gets copied to my output directory?

Currently, you can customize three things during the build:
- Whether the library gets copied or not
- Where the library is placed in the output folder
- Which plugins are copied

## Enable/Disable a copy for a specific configuration

Suppose you have a custom build platform named `MyFancyBuildPlatformx64` instead of the default `x64`.

This package doesn't know if it should copy x86 or x64 libraries for that unknown platform.
You have to tell msbuild explicitly.

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

You can change that to your liking:

Example : put libvlc to `native/x86`/`native/x64`
```
  <PropertyGroup>
    <VlcLib64TargetDir>native/x64</VlcLib64TargetDir>
    <VlcLib86TargetDir>native/x86</VlcLib86TargetDir>
  </PropertyGroup>
```

## Exclude some plugins from copy
Sometimes, you want to build a minimal package for one of these reasons:
- Reduce your package size
- Remove attacking surface of your software by limiting its features
- Speed up build times : Fastest copies are those that do not occur.
- Just because you don't need that plugin, it's cleaner not to copy it.

In your csproj, you can exclude some of the plugins by including them in a
`VlcExcludeWindowsPlugins` item group.
That exclusion will apply to all windows builds of libvlc (x86 and x64).

There is not such inclusion/exclusion mechanism for Android because libvlc is built as one monolithic library on this platform.

A few things to note:

- It's in an `ItemGroup`, not in a `PropertyGroup` as before
- Even if it's an exclude, we use `Include` to choose which plugins to exclude
- You may use wildcards, but you need to escape them as `%2A`

Some examples:
```
<ItemGroup>
  <!-- You can exclude plugin-by-plugin: -->
  <VlcExcludeWindowsPlugins Include="gui/libqt_plugin.dll" />

  <!-- You can exclude a whole folder -->
  <VlcExcludeWindowsPlugins Include="lua" />

  <!-- You can exclude with wildcards -->
  <VlcExcludeWindowsPlugins Include="%2A/%2Adummy%2A" />
</ItemGroup>
```

You can merge several VlcExcludeWindowsPlugins definitions into one with semicolons. This is equivalent to the three declarations above

```
<ItemGroup>
  <VlcExcludeWindowsPlugins Include="gui/libqt_plugin.dll;lua;%2A/%2Adummy%2A" />
</ItemGroup>
```

## Include selectively items
Another solution to achieve the goals mentioned above is to copy only the plugins that you want in your build.

The syntax is very similar, here are some examples:
```
<ItemGroup>
  <!-- Includes the codec folder. Notice how the wildcard is mandatory when doing include on folders -->
  <VlcIncludeWindowsPlugins Include="codec/%2A" />

  <!-- You can include plugin-by-plugin -->
  <VlcIncludeWindowsPlugins Include="audio_output/libdirectsound_plugin.dll" />

  <!-- You can include with wildcards all in d3d9/d3d11 -->
  <VlcIncludeWindowsPlugins Include="d3d%2A/%2A" />

  <!-- You can still exclude things from what you've included -->
  <VlcExcludeWindowsPlugins Include="codec/libddummy_plugin.dll" />
</ItemGroup>
```

Of course, you can group items with `;` as above
