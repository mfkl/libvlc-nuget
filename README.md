# libvlc for .NET
Nuget packaging setup for libvlc

This repository contains files and scripts related to nuget packaging for .NET projects using libvlc binaries.
For now, packages are hosted on myget.org. They will be available on nuget.org soon.

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
