using System.Reflection;
using System.Runtime.InteropServices;
using LibVLCSharp.Shared;

var method = typeof(Core).GetMethod("MacOSArchitectureFolder", BindingFlags.Static | BindingFlags.NonPublic)
             ?? throw new Exception("Companion loader patch is missing");
foreach (var (arch, expected) in new[] { (Architecture.X64, "osx-x64"), (Architecture.Arm64, "osx-arm64") })
{
    var actual = method.Invoke(null, new object[] { arch });
    if (!Equals(actual, expected)) throw new Exception($"{arch}: expected {expected}, got {actual}");
}
foreach (var arch in new[] { Architecture.X86, Architecture.Arm })
{
    try
    {
        method.Invoke(null, new object[] { arch });
        throw new Exception($"Unsupported architecture {arch} was accepted");
    }
    catch (TargetInvocationException e) when (e.InnerException is PlatformNotSupportedException) { }
}
Console.WriteLine("Loader architecture checks passed");
