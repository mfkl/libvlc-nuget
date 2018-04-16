# How to select which files are copied?

_**This page does not apply to Android builds**_

Sometimes, you want to build a minimal package for one of these reasons:
- Reduce your package size
- Remove attacking surface of your software by limiting its features
- Reduce the application loading time by making the plugins scan faster.
- Speed up build times: Fastest copies are those that do not occur.
- Just because you do not need that plugin, it is cleaner not to copy it.

## Exclude some files from copy
In your csproj, you can exclude some of the files by including them in a
`VlcExcludeWindowsFiles` item group.
That exclusion will apply to all windows builds of libvlc (x86 and x64).

There is not such inclusion/exclusion mechanism for Android because libvlc is built as one monolithic library on this platform.

Some examples:
```
<ItemGroup>
  <!-- You can exclude plugin-by-plugin: -->
  <VlcExcludeWindowsFiles Include="plugins/gui/libqt_plugin.dll" />

  <!-- You can exclude a whole folder -->
  <VlcExcludeWindowsFiles Include="plugins/lua" />

  <!-- You can exclude with wildcards -->
  <VlcExcludeWindowsPlugins Include="plugins/%2A/%2Adummy%2A" />
</ItemGroup>
```

You can merge several `VlcExcludeWindowsFiles` definitions into one with semicolons. This is equivalent to the three declarations above

```
<ItemGroup>
  <VlcExcludeWindowsFiles Include="plugins/gui/libqt_plugin.dll;plugins/lua;plugins/%2A/%2Adummy%2A" />
</ItemGroup>
```

A few things to note:

- You may use wildcards, but you need to escape them as `%2A`
- The syntax may be misleading, but the `VlcExclude...` item group requires the use of the `Include` attribute to choose which plugins to exclude. You are really adding string items to a list named "Exclude"

## Cherry-pick the files you need
You may also use an inclusive strategy to reach the goals defined above.

The syntax is very similar, here are some examples:
```
<ItemGroup>
  <!-- Includes the codec folder. Notice how the wildcard is mandatory when doing include on folders -->
  <VlcIncludeWindowsFiles Include="plugins/codec/%2A" />

  <!-- You can include plugin-by-plugin -->
  <VlcIncludeWindowsFiles Include="plugins/audio_output/libdirectsound_plugin.dll" />

  <!-- You can include with wildcards all in d3d9/d3d11 -->
  <VlcIncludeWindowsFiles Include="plugins/d3d%2A/%2A" />

  <!-- You can still exclude things from what you have included -->
  <VlcExcludeWindowsFiles Include="plugins/codec/libddummy_plugin.dll" />
</ItemGroup>
```

Of course, you can group items with `;` as with the exclusive strategy.

**Note**: This example is really dumb. You should probably  include at least `libvlccore.dll` and `libvlc.dll`.
The default value of `VlcIncludeWindowsFiles` is:

```
libvlc.dll;libvlccore.dll;plugins/%2A%2A
```
