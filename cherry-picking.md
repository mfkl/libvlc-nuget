# How to select which files are copied?

_**This page details operations that currently apply only to Windows builds**_

Sometimes, you want to build a minimal package for one of these reasons:
- Reduce your package size
- Remove attacking surface of your software by limiting its features
- Reduce the application loading time by making the plugins scan faster.
- Speed up build times: Fastest copies are those that do not occur.
- Just because you do not need that plugin, it is cleaner not to copy it.

## Exclude some files from copy
In your csproj, you can exclude some of the files by including them in a
`VlcWindowsX64ExcludeFiles` item group.
That exclusion will apply to the Windows x64 build of libvlc.

There is not such inclusion/exclusion mechanism for Android because libvlc is built as one monolithic library on this platform.

Some examples:
```
<ItemGroup>
  <!-- You can exclude plugin-by-plugin: -->
  <VlcWindowsX64ExcludeFiles Include="plugins\gui\libqt_plugin.dll" />

  <!-- You can exclude a whole folder. Notice how the wildcard is mandatory when doing exclude on folders -->
  <VlcWindowsX64ExcludeFiles Include="plugins\lua\%2A" />

  <!-- You can exclude with wildcards -->
  <VlcWindowsX64ExcludeFiles Include="plugins\%2A\%2Adummy%2A" />

  <!-- You can exclude the same files for Windows x86 -->
  <VlcWindowsX86ExcludeFiles Include="@(VlcWindowsX64ExcludeFiles)" />
</ItemGroup>
```

You can merge several `VlcWindowsX64ExcludeFiles` definitions into one with semicolons. This is equivalent to the declarations above

```
<ItemGroup>
  <VlcWindowsX64ExcludeFiles Include="plugins\gui\libqt_plugin.dll;plugins\lua\%2A;plugins\%2A\%2Adummy%2A" />
  <VlcWindowsX86ExcludeFiles Include="@(VlcWindowsX64ExcludeFiles)" />
</ItemGroup>
```

A few things to note:

- You may use wildcards, but you need to escape them as `%2A`
- Always use backslashes (`\`) rather than forward slashes (`/`), until this issue is resolved : [https://github.com/Microsoft/msbuild/issues/1024](https://github.com/Microsoft/msbuild/issues/1024)
- The syntax may be misleading, but the `...ExcludeFiles` item group requires the use of the `Include` attribute to choose which plugins to exclude. You are really adding string items to a list named "Exclude"

## Cherry-pick the files you need
You may also use an inclusive strategy to reach the goals defined above.

The syntax is very similar, here are some examples:
```
<ItemGroup>
  <!-- Includes the codec folder. Notice how the wildcard is mandatory when doing include on folders -->
  <VlcWindowsX64IncludeFiles Include="plugins\codec\%2A" />

  <!-- You can include plugin-by-plugin -->
  <VlcWindowsX64IncludeFiles Include="plugins\audio_output\libdirectsound_plugin.dll" />

  <!-- You can include with wildcards all in d3d9/d3d11 -->
  <VlcWindowsX64IncludeFiles Include="plugins\d3d%2A\%2A" />

  <!-- You can still exclude things from what you have included -->
  <VlcWindowsX64IncludeFiles Include="plugins\codec\libddummy_plugin.dll" />

  <!-- You can include the same files for Windows x86 -->
  <VlcWindowsX86IncludeFiles Include="@(VlcWindowsX64IncludeFiles)" />
</ItemGroup>
```

Of course, you can group items with `;` as with the exclusive strategy.

**Note**: This example is really dumb. You should probably  include at least `libvlccore.dll` and `libvlc.dll`.
The default value of `VlcWindowsX64IncludeFiles` and `VlcWindowsX86IncludeFiles` is:

```
libvlc.dll;libvlccore.dll;hrtfs\%2A%2A;locale\%2A%2A;lua\%2A%2A;plugins\%2A%2A
```
