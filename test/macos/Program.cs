using System.Runtime.InteropServices;
using LibVLCSharp.Shared;

string rid = RuntimeInformation.ProcessArchitecture == Architecture.Arm64 ? "osx-arm64" : "osx-x64";
string runtime = Dyld.RealPath(Path.Combine(AppContext.BaseDirectory, "libvlc", rid));

Core.Initialize();
using var vlc = new LibVLC();
Console.WriteLine($"{rid}: {vlc.Version}");

// libvlc must come from the package, not from another install. Compare real
// paths, as dyld and AppContext.BaseDirectory may differ in symlinks like /tmp.
var images = Enumerable.Range(0, (int)Dyld.ImageCount())
    .Select(i => Dyld.RealPath(Marshal.PtrToStringUTF8(Dyld.ImageName((uint)i)) ?? "/"))
    .ToList();
if (!images.Any(name => name.StartsWith(runtime) && name.EndsWith("libvlccore.dylib")))
    throw new Exception($"libvlccore was not loaded from {runtime}");

// Plugins link @rpath/libvlccore.dylib without an rpath of their own, so check
// that they loaded next to it rather than only that libvlc initialized.
if (!vlc.AudioOutputs.Any(output => output.Name == "auhal"))
    throw new Exception("The macOS audio output plugin did not load");
string plugins = Path.Combine(runtime, "lib", "vlc", "plugins");
Console.WriteLine($"{images.Count(name => name.StartsWith(plugins))} plugins loaded from {plugins}");

static class Dyld
{
    [DllImport("/usr/lib/libSystem.B.dylib", EntryPoint = "_dyld_image_count")]
    internal static extern uint ImageCount();
    [DllImport("/usr/lib/libSystem.B.dylib", EntryPoint = "_dyld_get_image_name")]
    internal static extern IntPtr ImageName(uint index);
    [DllImport("/usr/lib/libSystem.B.dylib", EntryPoint = "realpath")]
    static extern IntPtr RealPath(string path, IntPtr resolved);
    [DllImport("/usr/lib/libSystem.B.dylib", EntryPoint = "free")]
    static extern void Free(IntPtr pointer);

    internal static string RealPath(string path)
    {
        IntPtr resolved = RealPath(path, IntPtr.Zero);
        if (resolved == IntPtr.Zero)
            return Path.GetFullPath(path);
        try { return Marshal.PtrToStringUTF8(resolved)!; }
        finally { Free(resolved); }
    }
}
