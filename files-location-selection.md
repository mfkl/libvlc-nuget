# Specify the location where libvlc will be copied

_**This page details operations that currently apply only to Windows builds**_

The default locations are `libvlc/win-x64` and `libvlc/win-x86`

You can change that to your liking:

Example : put libvlc to `native/x86`/`native/x64`
```
  <PropertyGroup>
    <VlcWindowsX64TargetDir>native/x64</VlcWindowsX64TargetDir>
    <VlcWindowsX86TargetDir>native/x86</VlcWindowsX86TargetDir>
  </PropertyGroup>
```
