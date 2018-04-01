# `libvlc` for .NET

This repository is about presenting `libvlc` and its capabilities to .NET developers.
It also contains packaging tools and files for nuget packaging/deployment.

# What is libvlc?

`libvlc` is the multimedia framework powering the VLC applications. It is fully opensource, so other apps use it too.

You may find the documentation of the API here: https://www.videolan.org/developers/vlc/doc/doxygen/html/group__libvlc.html
it contains all modules, data structures and functions documentation to understand how to use the `libvlc` C API.

`libvlc` is modularized into hundreds of plugins, which may be loaded at runtime. This architecture provides great flexibility to developers (both VLC devs and dev consuming the library). The unified, complete and (somewhat) high level `libvlc` C API allows a wide range of operations, such as:
- Network browsing for distant filesystems (SMB, FTP, SFTP, NFS...).
- HDMI passthrough for Audio HD codecs, like E-AC3, TrueHD or DTS-HD.
- Stream to distant renderers, like Chromecast.
- 360 video and 3D audio playback with viewpoint change.
- Support for Ambisonics audio and more than 8 audio channels.
- Subtitles size modification live.
- Hardware decoding and display on all platforms.

Full list of features can be found here: https://www.videolan.org/vlc/releases/3.0.0.html

For now, packages are hosted on myget.org. They will be available on nuget.org soon.
Directory tree of what's included (dlls, headers, lib files) in the nuget can be found at https://github.com/mfkl/libvlc-nuget/blob/master/tree.md

Versioning of the nuget packages naturally follow the libvlc versioning.

#### 3.0.0: https://github.com/videolan/vlc-3.0/releases/tag/3.0.0

## Windows (7+) x86/x64 
```cmd
nuget install VideoLAN.LibVLC.Windows -Version 3.0.0 -Source https://www.myget.org/F/libvlc/api/v3/index.json 
```
https://www.myget.org/feed/libvlc/package/nuget/VideoLAN.LibVLC.Windows

*Note: if you intend to use libvlc with UWP projects, you probably need to install the WindowsRT package instead because this build directly uses win32 APIs.*


To-do:
- Android
- iOS
- macOS
- WindowsRT x86/x64 (10)
- Linux
