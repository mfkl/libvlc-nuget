# LibVLC for UWP

As it is native code, you will need to use a wrapper library such as [LibVLCSharp](https://code.videolan.org/videolan/LibVLCSharp) to use it from .NET.

## What is libvlc?

`libvlc` is the multimedia framework powering the VLC applications. It is fully opensource, so other apps use it too.

**API documentation**: https://www.videolan.org/developers/vlc/doc/doxygen/html/group__libvlc.html

it contains all modules, data structures and functions documentation to understand how to use the `libvlc` C API.

The **source** is in the main VLC repository: https://github.com/videolan/vlc

`libvlc` is *modularized* into hundreds of plugins, which may be loaded at runtime. This architecture provides great flexibility to developers (both VLC devs and devs consuming the library). The unified, complete and (somewhat) high level `libvlc` C API allows a wide range of operations, such as:

- Play every media file formats, every codec and every streaming protocols
- Run on every platform, from desktop (Windows, Linux, Mac) to mobile (Android, iOS) and TVs
- Hardware and efficient decoding on every platform, up to 8K
- Network browsing for distant filesystems (SMB, FTP, SFTP, NFS...) and servers (UPnP, DLNA)
- Playback of Audio CD, DVD and Bluray with menu navigation
- Support for HDR, including tonemapping for SDR streams
- Audio passthrough with SPDIF and HDMI, including for Audio HD codecs, like DD+, TrueHD or DTS-HD
- Support for video and audio filters
- Support for 360 video and 3D audio playback, including Ambisonics
- Able to cast and stream to distant renderers, like Chromecast and UPnP renderers.

Full list of the new 3.0 features can be found here: https://www.videolan.org/vlc/releases/3.0.0.html

```cmd
dotnet add package VideoLAN.LibVLC.UWP
```

[![NuGet Stats](https://img.shields.io/nuget/v/VideoLAN.LibVLC.UWP.svg)](https://www.nuget.org/packages/VideoLAN.LibVLC.UWP)
[![NuGet Stats](https://img.shields.io/nuget/dt/VideoLAN.LibVLC.UWP.svg)](https://www.nuget.org/packages/VideoLAN.LibVLC.UWP)

## Supported CPU architectures

- i386
- x86_64
- ARMv7
