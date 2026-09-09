using System.Runtime.InteropServices;
using LibVLCSharp.Shared;

if (!OperatingSystem.IsMacOS()) throw new PlatformNotSupportedException("Run playback tests on macOS");
string rid = RuntimeInformation.ProcessArchitecture switch
{
    Architecture.X64 => "osx-x64",
    Architecture.Arm64 => "osx-arm64",
    _ => throw new PlatformNotSupportedException()
};
string runtime = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "libvlc", rid));
if (Environment.GetEnvironmentVariable("SMOKE_EXPECTED_RID") != rid)
    throw new Exception($"Unexpected process architecture: {rid}");
#if MACOS
const string target = "net8.0-macos";
// Compile-time proof that NuGet selected the Apple assembly, not net8.0 fallback.
Console.WriteLine(typeof(LibVLCSharp.Platforms.Mac.VideoView).FullName);
#else
const string target = "net8.0";
if (typeof(Core).Assembly.GetType("LibVLCSharp.Platforms.Mac.VideoView") != null)
    throw new Exception("Desktop test resolved an Apple assembly");
#endif
if (Environment.GetEnvironmentVariable("SMOKE_EXPECTED_TFM") != target)
    throw new Exception($"Unexpected managed target: {target}");
Console.WriteLine($"Testing {target}, {rid}, base directory {AppContext.BaseDirectory}");
Core.Initialize(); // Acceptance requirement: no explicit native or plugin path.
using var vlc = new LibVLC("--no-video-title-show", "--no-osd");
if (!vlc.Version.StartsWith("3.0.23")) throw new Exception(vlc.Version);
foreach (string input in args)
{
    using var media = new Media(vlc, new Uri(input));
    using var player = new LibVLCSharp.Shared.MediaPlayer(vlc);
    using var ended = new ManualResetEventSlim();
    string? error = null;
    long audioSamples = 0;
    long videoFrames = 0;
    IntPtr pixels = Marshal.AllocHGlobal(64 * 64 * 4);
    player.SetAudioFormat("S16N", 48000, 1);
    player.SetAudioCallbacks((_, _, count, _) => Interlocked.Add(ref audioSamples, count), null, null, null, null);
    player.SetVideoFormat("RV32", 64, 64, 64 * 4);
    player.SetVideoCallbacks((_, planes) => { Marshal.WriteIntPtr(planes, pixels); return IntPtr.Zero; },
                            null, (_, _) => Interlocked.Increment(ref videoFrames));
    player.EndReached += (_, _) => ended.Set();
    player.EncounteredError += (_, _) => { error = "Playback error"; ended.Set(); };
    try
    {
        if (!player.Play(media)) throw new Exception("Play returned false");
        if (!ended.Wait(TimeSpan.FromSeconds(45))) throw new Exception("Playback timed out");
        player.Stop();
        if (error != null) throw new Exception(error);
        if (audioSamples == 0 || videoFrames == 0)
            throw new Exception($"No decoded output: audio={audioSamples}, video={videoFrames}");
        Console.WriteLine($"Decoded {input}: audio={audioSamples}, frames={videoFrames}");
    }
    finally
    {
        player.Stop();
        Marshal.FreeHGlobal(pixels);
    }
}
// Verify all loaded VLC/plugin images originate in this package's matching tree.
bool foundCore = false, foundPlugin = false;
for (uint i = 0; i < Dyld.ImageCount(); i++)
{
    string name = Marshal.PtrToStringUTF8(Dyld.ImageName(i)) ?? "";
    if (!Path.GetFileName(name).StartsWith("libvlc") && !name.Contains("_plugin.dylib")) continue;
    string full = Path.GetFullPath(name);
    if (!full.StartsWith(runtime + Path.DirectorySeparatorChar, StringComparison.Ordinal))
        throw new Exception($"Loaded native library outside {runtime}: {full}");
    foundCore |= Path.GetFileName(full).StartsWith("libvlccore");
    foundPlugin |= full.Contains("_plugin.dylib");
}
if (!foundCore || !foundPlugin) throw new Exception("Core/plugin image verification did not run");
Console.WriteLine($"PASS {target} {rid}: {vlc.Version}");

static class Dyld
{
    [DllImport("/usr/lib/libSystem.B.dylib", EntryPoint = "_dyld_image_count")]
    internal static extern uint ImageCount();
    [DllImport("/usr/lib/libSystem.B.dylib", EntryPoint = "_dyld_get_image_name")]
    internal static extern IntPtr ImageName(uint index);
}
