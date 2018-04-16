# Specify the location where libvlc will be copied

_**This page does not apply to Android builds**_

The default locations are `libvlc/win-x64` and `libvlc/win-x86`

You can change that to your liking:

Example : put libvlc to `native/x86`/`native/x64`
```
  <PropertyGroup>
    <VlcLib64TargetDir>native/x64</VlcLib64TargetDir>
    <VlcLib86TargetDir>native/x86</VlcLib86TargetDir>
  </PropertyGroup>
```
