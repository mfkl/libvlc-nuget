using System.Runtime.InteropServices;
using LibVLCSharp.Shared;

string rid = RuntimeInformation.ProcessArchitecture == Architecture.Arm64 ? "osx-arm64" : "osx-x64";
string runtime = Path.Combine(AppContext.BaseDirectory, "libvlc", rid);

Core.Initialize();
using var vlc = new LibVLC();
Console.WriteLine($"{rid}: {vlc.Version}");

// libvlc must come from the package, not from another install.
bool packaged = false;
for (uint i = 0; i < Dyld.ImageCount(); i++)
{
    string name = Path.GetFullPath(Marshal.PtrToStringUTF8(Dyld.ImageName(i)) ?? "");
    packaged |= name.StartsWith(Path.GetFullPath(runtime)) && name.EndsWith("libvlccore.dylib");
}
if (!packaged) throw new Exception($"libvlccore was not loaded from {runtime}");

static class Dyld
{
    [DllImport("/usr/lib/libSystem.B.dylib", EntryPoint = "_dyld_image_count")]
    internal static extern uint ImageCount();
    [DllImport("/usr/lib/libSystem.B.dylib", EntryPoint = "_dyld_get_image_name")]
    internal static extern IntPtr ImageName(uint index);
}
