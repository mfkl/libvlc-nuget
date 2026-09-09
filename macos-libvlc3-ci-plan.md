# macOS LibVLC 3 CI and NuGet packaging plan

## Implementation status

The local implementation is on branch `ci/macos-libvlc3-lgpl`. See
[buildsystem/macos/README.md](buildsystem/macos/README.md) for workflow operation,
preview packages, the companion LibVLCSharp patch, and validation limits.
Native macOS compilation, relocation/signature checks, and playback are pending
the first GitHub Actions run. CI tests both `net8.0` desktop and `net8.0-macos`
app bundles on each native architecture: four required playback jobs. Legacy
bundles, hardware decoding and visible rendering require further Mac validation
before a general release.

## Goal and agreed requirements

Build LibVLC directly from VLC tag `3.0.23` and distribute one macOS NuGet package that works on Intel x64 and Apple Silicon arm64. Users should only need the package reference and normal LibVLCSharp initialization. Build and publish output must contain everything needed for playback without an installed VLC application, manual file copying, custom library paths, or environment variables.

- Pin VLC tag `3.0.23` and verify commit `578d28f6c9f2379164516e689418f92ac74a3445`.
- Distribute separate x64 and arm64 runtime trees, each containing `libvlc.dylib`, `libvlccore.dylib`, dynamic plugins, and required dependencies. Do not combine them into a single monolithic library or universal binaries.
- Exclude GPL components; LGPLv3 dependencies are acceptable.
- Build and validate both architectures with both `net8.0` and `net8.0-macos` consumers.
- LibVLCSharp loading may be modified if necessary to support both architectures. Preserve the existing loader when it already supports the chosen package layout reliably.
- Use the existing `dlopen` loading approach without `SetDllImportResolver`. After successful native builds, CI must verify normal LibVLCSharp initialization, P/Invoke resolution, and playback against the packaged libraries on both architectures.

## 1. Confirm the loading and packaging design

Use separate `osx-x64` and `osx-arm64` directories in one NuGet package. Each runtime tree contains single-architecture libraries and plugins. Keep both trees isolated through build, packaging, copying, and loading.

LibVLCSharp's inspected 3.x loader uses a fixed macOS search path rather than selecting separate x64 and arm64 directories. Validate the actual released versions against the new layout, and implement the necessary loader changes and tests in the LibVLCSharp repository if they do not already support it.

Select architecture based on the process, not the machine or build host: an arm64 process loads `osx-arm64`, and an x64 process loads `osx-x64`, including under Rosetta. Resolve libraries relative to the application output and load plugins and dependencies from the same architecture tree. Do not fall back to the other architecture. Coordinate the minimum supported LibVLCSharp version and package release order. Users must not need to choose native paths in application code.

Validate automatic loading with a small consuming app before completing the package targets. The separate-architecture design is an agreed requirement.

## 2. Pin the build environment

Select explicit macOS runner and Xcode versions for Intel and Apple Silicon. Set and record deployment targets for each architecture; validate compatibility with the selected SDK and dependencies rather than inheriting the README's historical minimum macOS version.

Record the VLC tag and commit, runner image information, Xcode and SDK versions, deployment targets, build configuration, and patches in the artifacts. Keep the macOS VLC pin independent of the existing iOS VLCKit version detection.

## 3. Define the LGPL build configuration

Start from `extras/package/apple/build.sh` at the pinned tag, using `--enable-shared`. Its contrib configuration already includes `--disable-gpl`, but also starts with `--disable-all` and only a small dependency selection. Define the required playback dependencies explicitly.

- Keep contrib's `--disable-gpl`; allow LGPLv3 dependencies.
- Enable the agreed common playback, network, subtitle, and hardware decoding features.
- Review both third-party dependencies and VLC modules for the distributed license set. The contrib flag alone does not establish the license of all packaged files.
- Exclude GPL dependencies and modules, including modules requiring removal after installation. The upstream shared build exits before its static module-removal stage.
- Build contribs from source with the selected configuration; reuse only caches or prebuilt artifacts produced from that same configuration.
- Maintain a manifest of shipped modules, dependencies, versions, and licenses, and make packaging checks reject excluded components.

Start without VLCKit patches. Add individual patches only for a required feature or a reproducible build/runtime failure, checking whether each fix is already present at the pinned VLC revision. Record why each patch is needed.

## 4. Build x64 and arm64 in GitHub Actions

Add independent architecture jobs using the same feature configuration. Put the build logic in reusable scripts and keep the workflow focused on orchestration.

Cache tools and contribs using keys that include architecture, source revision, toolchain, configuration, and patches. Upload each architecture's installed libraries, plugins, runtime data, build manifest, and diagnostic logs.

## 5. Assemble relocatable runtimes for each architecture

Stage each architecture independently. Check module parity and explicitly account for architecture-specific module differences. Verify that every shipped Mach-O binary has exactly the expected architecture. Do not merge binaries with `lipo`.

Bundle all required non-system dependencies and runtime data. Rewrite install names and dependency paths to resolve relative to the packaged libraries. Preserve automatic plugin and data discovery, and remove dependencies on build directories, Homebrew installations, or an installed VLC application.

Normalize versioned library aliases for NuGet packaging instead of depending on archive extraction preserving symlinks. Omit or regenerate plugin caches as appropriate for the final layout; do not ship a cache tied to the build tree.

Apply ad-hoc signatures after modifying binaries, then verify signatures. Ensure subsequent application signing can include the native libraries and plugins correctly.

Apply the same relocation and packaging checks to each runtime tree and validate automatic process-architecture selection in LibVLCSharp. Reject dependencies that cross from one architecture tree into the other.

## 6. Make NuGet build and publish work automatically

Update `VideoLAN.LibVLC.Mac.nuspec` and `build/VideoLAN.LibVLC.Mac.targets` to include and copy the complete runtime into locations discovered automatically by the supported LibVLCSharp versions.

- Preserve plugin and data directory structure during `dotnet build` and `dotnet publish`.
- Support builds without a runtime identifier and publishes targeting `osx-x64` or `osx-arm64`.
- For builds and portable publishes without a runtime identifier, copy both trees and let LibVLCSharp select the process architecture automatically.
- For an explicit `osx-x64` or `osx-arm64` runtime identifier, copy only the matching runtime tree while preserving its expected directory layout. Use the target runtime identifier rather than the build host architecture, including when cross-publishing.
- Preserve and validate the existing Xamarin.Mac app-bundle integration, including native dependency copying and application signing order.
- Avoid stale or duplicate native files when rebuilding, changing runtime identifiers, or publishing.
- Update package metadata and include applicable license notices and source information.

Check published package versions before selecting the new NuGet version. The current nuspec contains `3.1.3.1`, so assigning `3.0.23` without checking upgrade ordering could prevent existing users from receiving the new package. Record the native VLC version separately from any package revision needed for monotonic upgrades.

## 7. Validate the actual NuGet package

Restore the generated `.nupkg` into a small consuming app using a pinned, released LibVLCSharp version. If a loader change is required, also validate the coordinated LibVLCSharp package and document its minimum version.

Run integration tests on native Intel and Apple Silicon runners against:

- Ordinary build output without an explicit runtime identifier.
- Framework-dependent publish for the matching runtime identifier.
- Self-contained publish for the matching runtime identifier.
- The final application bundle for the supported bundle integration.

Use a four-job matrix (`osx-x64` / `osx-arm64` × `net8.0` / `net8.0-macos`).
Build the companion LibVLCSharp package with both managed targets and require
the Apple consumer to reference an Apple-only type to prevent desktop fallback.
For `net8.0-macos`, execute both built and published `.app` executables with an
explicit single RID. Gate the validated package artifact on all four jobs after
successful native builds and packaging.

Assert that portable output contains both isolated runtime trees and that output targeting a runtime identifier contains only the matching tree. Verify automatic architecture selection, including an x64 process under Rosetta where available, and confirm that no library or plugin loads from the other architecture tree. Test cross-publishing file selection independently of native execution.

Require successful normal initialization, the expected native version, and actual audio/video decoding using small checked-in fixtures with documented provenance. Exercise representative container, codec, and subtitle plugins, and test network playback against a local test server. Verify hardware decoding and native rendering separately where runner capabilities permit; report any validation limitations.

Move the output to a different directory, launch it with an unrelated working directory, and verify the loaded libraries originate from the package. Run with no installed VLC dependency, custom initialization path, `VLC_PLUGIN_PATH`, or `DYLD_LIBRARY_PATH`.

Check packaged architectures, native dependency resolution, signatures, plugin discovery, and the license manifest. A successful compile or `libvlc_new` call alone is not sufficient evidence of working playback.

## 8. Produce artifacts and documentation

Upload the validated NuGet package, source/build manifest, corresponding source bundle, applicable notices, and diagnostic logs. Keep NuGet publication separate from CI artifact creation.

Document supported macOS and LibVLCSharp versions, included features, ordinary package consumption, and app-bundle/signing integration. If LibVLCSharp changes are necessary, coordinate their tests, release notes, and release order with the native package.

## Acceptance criteria

The same macOS NuGet package contains separate single-architecture x64 and arm64 runtime trees and restores, builds, publishes, and plays media on Intel and Apple Silicon using normal LibVLCSharp initialization. The consuming process automatically loads its matching libraries and plugins. All native dependencies and plugins are supplied automatically, loaded from the distributed output, and conform to the selected LGPL-compatible component set. Any required LibVLCSharp loader changes are included in the coordinated implementation and verified end to end. No universal or monolithic LibVLC binary is produced.

## References

- [VideoLAN macOS release page](https://images.videolan.org/vlc/download-macosx.html)
- [VLC source at tag 3.0.23](https://code.videolan.org/videolan/vlc/-/tree/3.0.23)
- [LibVLCSharp 3.x loader](https://github.com/videolan/libvlcsharp/blob/3.x/src/LibVLCSharp/Shared/Core/Core.cs)
- [VLCKit 3.x patches](https://github.com/videolan/vlckit/tree/3.0/libvlc/patches)
- [NuGet native file packaging](https://learn.microsoft.com/en-us/nuget/create-packages/native-files-in-net-packages)
