# Enable/Disable a copy for a specific configuration

_**This page details operations that currently apply only to Windows builds**_

Why?

- Suppose you have a custom build platform named `MyFancyBuildPlatformx64` instead of the default `x64`.
- Suppose you release a project that builds against `AnyCPU`, but that you know that it will always run on `x64` windows.

This package doesn't know if it should copy x86 or x64 libraries in those cases.
You have to tell msbuild explicitly.

In your csproj, you can define the `<VlcWindowsX64Enabled>` property.
(`<VlcWindowsX86Enabled>` is also available, as you guessed it, for x86)

Examples:

Adding x64 libraries for the `MyFancyBuildPlatformx64` platform:
```
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|MyFancyBuildPlatformx64'">
    <VlcWindowsX64Enabled>true</VlcWindowsX64Enabled>
  </PropertyGroup>
```

Don't copy x86 libraries for the AnyCPU builds:

```
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|AnyCPU'">
    <VlcWindowsX86Enabled>false</VlcWindowsX86Enabled>
  </PropertyGroup>
```
