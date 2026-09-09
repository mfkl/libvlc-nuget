# macOS LibVLC 3 preview builds

This workflow builds VLC **3.0.23** directly, with GPL dependencies disabled and
LGPLv3 dependencies permitted. It packages separate **osx-x64** and **osx-arm64**
runtime trees in `VideoLAN.LibVLC.Mac.3.1.3.2-macos.1.nupkg`. Each tree contains
LibVLC, its core, selected dynamic plugins, runtime data and license notices.
The initial deployment target is macOS 11.0 for both architectures.

This is a preview implementation. Native compilation and playback must pass the
GitHub Mac jobs before distributing the packages. There is no NuGet publishing
step. Runner images change over time; the source commit and Xcode version are
checked, and the actual runner image/SDK are recorded in the build manifest.

## Run the workflow

Push this branch to GitHub to trigger **macOS LibVLC 3 (LGPL)**, or run it through
`workflow_dispatch` on a branch containing `.github/workflows/macos-libvlc3.yml`.
No PR is necessary. The existing iOS/UWP workflow is independent and may also run
on a branch push under its existing triggers.

The workflow builds each architecture on a native macOS 15 runner with Xcode
16.4. It retains build logs, matching source archives, and intermediate packages.
Only after all four playback jobs pass does it create `macos-nuget-validated`, which
contains the native package and the companion LibVLCSharp preview package.

| Consumer target | Intel runner (`osx-x64`) | Apple Silicon runner (`osx-arm64`) |
| --- | --- | --- |
| `net8.0` | Portable build, framework-dependent and self-contained publish | Portable build, framework-dependent and self-contained publish |
| `net8.0-macos` | Build and publish a single-architecture `.app` | Build and publish a single-architecture `.app` |

Playback waits for both native builds, the combined native package, and the
companion managed package. Each job restores those packages into a fresh consumer,
checks the selected architecture and managed target, relocates the output, and
decodes local MP4/MKV plus HTTP media with normal LibVLCSharp initialization.
Apple tests launch the `.app` executable and reference the Apple-only `VideoView`
type, so a fallback to the desktop assembly cannot pass. Build logs and MSBuild
binary logs are uploaded for diagnosis.

The Apple companion and consumers use .NET SDK **8.0.424**, workload set
**8.0.402.1** (macOS SDK **15.0.8303**), and **Xcode 16.0**, as required by the
[pinned Apple SDK release](https://github.com/dotnet/macios/releases/tag/dotnet-8.0.1xx-xcode16.0-8303).
`apple/global.json` and `setup-apple-tests.sh` pin this toolchain separately from
the native VLC compiler. Each Apple consumer specifies one runtime identifier.

## LibVLCSharp compatibility

Released LibVLCSharp 3.10.1 does not automatically select the separate macOS RID
directories. `libvlcsharp-macos-loading.patch` is a companion change against its
pinned commit in `versions.json`. It chooses the **process** architecture, searches
the application directory, and preserves legacy flat layouts. It uses the existing
`dlopen` mechanism without `SetDllImportResolver`; CI checks subsequent P/Invoke
calls as well as library discovery. It also enables the shared loader for the
MAC compilation path. It never searches the other architecture's directory.

CI clones LibVLCSharp into an isolated directory, applies this patch, and builds
`LibVLCSharp.3.10.2-macos.1.nupkg` targeting **net8.0** and **net8.0-macos** for
the integration tests. The patch is kept here for review and coordinated integration into the
LibVLCSharp repository; that repository's working checkout is not modified.
The companion is a CI preview, not a replacement for a full multi-target
LibVLCSharp release. Coordinate that release before publishing the native package
for general consumption.

For a preview .NET 8 desktop app, put both validated packages in a local NuGet
feed and reference:

```xml
<PackageReference Include="VideoLAN.LibVLC.Mac" Version="3.1.3.2-macos.1" />
<PackageReference Include="LibVLCSharp" Version="3.10.2-macos.1" />
```

Use normal `Core.Initialize()` / `new LibVLC()` calls. Do not set an explicit
LibVLC path or `VLC_PLUGIN_PATH`. Portable output contains both trees. Publishing
with `-r osx-x64` or `-r osx-arm64` copies only the requested tree. In a modern
macOS `.app`, this tree goes in `Contents/MonoBundle` beside the assemblies:

```text
libvlc/
  osx-x64/                    # or osx-arm64; both in portable output
    lib/
      libvlc.dylib
      libvlccore.dylib
      <other non-system dynamic dependencies>
      vlc/plugins/<category>/*_plugin.dylib
      vlc/share/...
    licenses/...
    build-manifest.json
```

Set `VlcMacEnabled=false` to disable copying. Native files remain external files
in publish output. Single-file extraction, NativeAOT, hardened/notarized app
bundles and the legacy Xamarin.Mac integration require separate validation.
CI covers ordinary .NET desktop output and ad-hoc-signed modern macOS app bundles.
The existing Xamarin.Mac copying hook is retained with the full runtime tree,
but its signing order requires a separate legacy test. All native playback,
including the modern MAC loader path, remains unverified until CI passes.

## Build configuration and distribution

`versions.json` pins source revisions, preview versions and Xcode. `build.conf`
selects contribs and disables GPL-backed features. `plugins.json` defines required
and optional distributed modules. `vlc-macos-linker.patch` reserves Mach-O header
space for relocation of library install names. `vlc-macos-tools.patch` builds
VLC's pinned pkg-config tool and its Autoconf macros together, preventing a host
pkg-config executable from leaving contribs without `pkg.m4`.
The build may compile additional VLC modules;
staging ships only the selected ones and audits the source notices of their
compiled translation units and local convenience libraries. Unknown/GPL notices,
missing required modules, host dependencies and mixed architectures fail staging.
This is a technical packaging guard, not a complete automated license review.
Review all included third-party notices before a public release.

FreeType uses the **FreeType Project License (FTL)** alternative. The contrib
option `--enable-ad-clauses` selects that path while `--disable-gpl` remains in
effect. The build manifest records both settings, and each runtime includes the
FTL text, additional FreeType notices and credit under `licenses/freetype2`.
This software is based in part on the work of the FreeType Team
(https://freetype.org/). Applications redistributing the runtime must retain the
credit in their distribution documentation. See [FreeType's licensing options](https://freetype.org/license.html).

The selected features cover FFmpeg-based decoding, MP4/MKV/AVI/Ogg playback,
HTTP(S)/RTSP, subtitles and macOS outputs. GPL components such as x264/x265 and
DVD navigation are excluded. Actual feature availability is recorded in each
manifest; required modules must exist for a build to pass. The smoke tests decode
synthetic MPEG-4/AAC MP4 and MKV media, including over local HTTP, using audio and
video callbacks. Subtitles, hardware decoding, RTSP and visible rendering are
not yet exercised by playback tests.

Source artifacts include the pinned VLC source, contrib archives and patches,
and these packaging scripts. Publish matching sources and notices alongside any
binary release. The native package's preview version follows the existing
3.1.3.1 package; the actual engine version is independently pinned to 3.0.23.

## Local checks

```sh
python3 -m unittest discover -s buildsystem/macos/tests -v
for script in buildsystem/macos/*.sh; do bash -n "$script"; done
bash buildsystem/macos/build-libvlcsharp.sh
```

On a native Mac with the pinned Xcode selected:

```sh
bash buildsystem/macos/build.sh osx-arm64 # osx-x64 on Intel
```

To build the two-target companion and run consumers on a Mac with both pinned
Xcodes and .NET SDKs installed (after packing the native runtimes):

```sh
bash buildsystem/macos/setup-apple-tests.sh
bash buildsystem/macos/build-libvlcsharp.sh --with-macos
bash buildsystem/macos/test-package.sh osx-arm64 net8.0
bash buildsystem/macos/test-package.sh osx-arm64 net8.0-macos
```

The default `build-libvlcsharp.sh` invocation builds only the desktop target for
local checks on Windows/Linux; CI always uses `--with-macos`.

Builds and downloads live under ignored `.macos-work/`. Staging requires a fresh
destination to avoid accidentally mixing old and new binary files. To update
LibVLCSharp, rebase the companion patch and update its tag/commit/version in
`versions.json`; never silently follow a moving branch.
