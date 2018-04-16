# Enable/Disable a copy for a specific configuration

_**This page does not apply to Android builds**_

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
