#tool nuget:?package=NUnit.ConsoleRunner&version=3.4.0

//////////////////////////////////////////////////////////////////////
// ARGUMENTS
//////////////////////////////////////////////////////////////////////

var target = Argument("target", "Default");
var configuration = Argument("configuration", "Release");

//////////////////////////////////////////////////////////////////////
// PREPARATION
//////////////////////////////////////////////////////////////////////

var nightlyVersion = "vlc-4.0.0-dev";

var artifactsLocation = Directory("../artifacts");
var packageLocationX64 = Directory("../build/win7-x64/native");
var packageLocationX86 = Directory("../build/win7-x86/native");

string todayPartialLink = null;
const string ext = ".7z";
string packageVersionWin32 = null;
string packageVersionWin64 = null;
string WindowsPackageName = "VideoLAN.LibVLC.Windows";
string nupkg = "nupkg";
string FeedzSourceURL = "https://f.feedz.io/videolan/preview/nuget/index.json";
string FEEDZ = "FEEDZ";


//////////////////////////////////////////////////////////////////////
// TASKS
//////////////////////////////////////////////////////////////////////

Task("Clean")
    .Does(() =>
{
    CleanDirectory(artifactsLocation);
    CleanDirectory(packageLocationX64);
    CleanDirectory(packageLocationX86);
    DeleteFiles(GetFiles($"./*.{nupkg}"));
    // if(FileExists($"{artifact}.{ext}"))
    //     DeleteFile($"{artifact}.{ext}");
});

Task("Package-windows-classic-nightly")
    .IsDependentOn("Clean")
    .IsDependentOn("Download-win32-nightly")
    .IsDependentOn("Download-win64-nightly")
    .Does(() =>
{
    CreateNuGetPackage();
});

Task("Download-win32-nightly")
    .Does(async () =>
{
    await DownloadArtifact("win32-llvm");
});

Task("Download-win64-nightly")
    .IsDependentOn("Clean")
    .Does(async () =>
{
    await DownloadArtifact("win64-llvm");
});

Task("Publish")
    .IsDependentOn("Package-windows-classic-nightly")
    .Does(() =>
{
    var nugetPushSettings = new NuGetPushSettings 
    {
        Source = FeedzSourceURL,
        ApiKey = EnvironmentVariable(FEEDZ),
        SkipDuplicate = true
    };

    if(IsPrBuild())
    {
        Console.WriteLine("Don't actually deploy on PR builds!");
    }
    else
    {
        Console.WriteLine($"Attempting to push ./{WindowsPackageName}.{packageVersionWin64}.{nupkg}");
        NuGetPush($"./{WindowsPackageName}.4.0.0-alpha-{packageVersionWin64}.{nupkg}", nugetPushSettings);   
    }
});

bool IsPrBuild()
{
    if(!BuildSystem.AzurePipelines.IsRunningOnAzurePipelines) return false;

    return BuildSystem.AzurePipelines.Environment.PullRequest.Number > 0;
}

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Diagnostics;

// download and extract nightly build.
async Task DownloadArtifact(string arch)
{
    Console.WriteLine("Figuring out URL... ");
    const string baseUrl = "https://artifacts.videolan.org/vlc/nightly-";
    string page;

    var today = DateTime.Today.ToString("yyyyMMdd");   

    var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
    HttpResponseMessage result;
    string url = null;

    url = $"{baseUrl}{arch}/";
    Console.WriteLine($"requesting {url}");
    result = await client.GetAsync(url);

    page = await result.Content.ReadAsStringAsync();
    todayPartialLink = ExtractLinks(page).Find(url => url.StartsWith(today));

    Console.WriteLine($"found partial link: {todayPartialLink}");

    url = $"{baseUrl}{arch}/{todayPartialLink}";
    Console.WriteLine($"requesting {url}");

    result = await client.GetAsync(url);
    page = await result.Content.ReadAsStringAsync();

    var todayLinkEnding = ExtractLinks(page).First(url => url.EndsWith(ext));
    if (todayLinkEnding == null) throw new NullReferenceException();

    client.Dispose();
    string artifact = string.Empty;

    if(arch.StartsWith("win32"))
    {
        packageVersionWin32 = today;
        artifact = $"artifact-{packageVersionWin32}-{arch}";
    }
    else if(arch.StartsWith("win64"))
    {
        packageVersionWin64 = today;
        artifact = $"artifact-{packageVersionWin64}-{arch}";
    }   

    Console.WriteLine("Found the nightly artifact URL");

    using (var httpClient = new HttpClient())
    {
        url = $"{baseUrl}{arch}/{todayPartialLink}{todayLinkEnding}";
        Console.WriteLine($"requesting {url}");

        using (var stream = await httpClient.GetStreamAsync(url))
        {
            using (var fs = new FileStream($"../artifacts/{artifact}{ext}", FileMode.CreateNew))
            {
                await stream.CopyToAsync(fs);
            }
        }
        Console.WriteLine(Environment.NewLine);
        Console.WriteLine("Done...");
    }

    ProcessStartInfo p = new ProcessStartInfo();
    p.FileName = "/usr/bin/7z";
    p.Arguments = $"x ../artifacts/{artifact}{ext} -o../artifacts/{artifact}";
    p.WindowStyle = ProcessWindowStyle.Hidden;
    Process x = Process.Start(p);
    x.WaitForExit();
}

// move files in proper locations for nuget pack
void PrepareForPackaging()
{
    Console.WriteLine("PrepareForPackaging...");

    var artifactwin32 = $"../artifacts/artifact-{packageVersionWin32}-win32-llvm";
    var artifactwin64 = $"../artifacts/artifact-{packageVersionWin64}-win64-llvm";

    var libsWin32 = new []
    { 
        $"./{artifactwin32}/{nightlyVersion}/libvlc.dll", 
        $"./{artifactwin32}/{nightlyVersion}/libvlccore.dll"
    };

    var libsWin64 = new []
    {
        $"./{artifactwin64}/{nightlyVersion}/libvlc.dll", 
        $"./{artifactwin64}/{nightlyVersion}/libvlccore.dll" 
    };

    var directories = new [] 
    {
        Directory($"./{artifactwin32}/{nightlyVersion}/hrtfs"),
        Directory($"./{artifactwin32}/{nightlyVersion}/lua"),
        Directory($"./{artifactwin32}/{nightlyVersion}/plugins"),
        Directory($"./{artifactwin32}/{nightlyVersion}/sdk/lib"),
        Directory($"./{artifactwin32}/{nightlyVersion}/sdk/include"),

        Directory($"./{artifactwin64}/{nightlyVersion}/hrtfs"),
        Directory($"./{artifactwin64}/{nightlyVersion}/lua"),
        Directory($"./{artifactwin64}/{nightlyVersion}/plugins"),
        Directory($"./{artifactwin64}/{nightlyVersion}/sdk/lib"),
        Directory($"./{artifactwin64}/{nightlyVersion}/sdk/include")
    };

    Console.WriteLine("Copying files for packaging... ");
    CopyFiles(libsWin64, packageLocationX64);
    CopyFiles(libsWin32, packageLocationX86);

    CopyDirectory(Directory($"./{artifactwin32}/{nightlyVersion}/hrtfs"), Directory($"{packageLocationX86}/hrtfs"));
    CopyDirectory(Directory($"./{artifactwin32}/{nightlyVersion}/lua"), Directory($"{packageLocationX86}/lua"));
    CopyDirectory(Directory($"./{artifactwin32}/{nightlyVersion}/plugins"), Directory($"{packageLocationX86}/plugins"));
    CopyDirectory(Directory($"./{artifactwin32}/{nightlyVersion}/sdk/lib"), Directory($"{packageLocationX86}/sdk/lib"));
    CopyDirectory(Directory($"./{artifactwin32}/{nightlyVersion}/sdk/include"), Directory($"{packageLocationX86}/sdk/include"));

    CopyDirectory(Directory($"./{artifactwin64}/{nightlyVersion}/hrtfs"), Directory($"{packageLocationX64}/hrtfs"));
    CopyDirectory(Directory($"./{artifactwin64}/{nightlyVersion}/lua"), Directory($"{packageLocationX64}/lua"));
    CopyDirectory(Directory($"./{artifactwin64}/{nightlyVersion}/plugins"), Directory($"{packageLocationX64}/plugins"));
    CopyDirectory(Directory($"./{artifactwin64}/{nightlyVersion}/sdk/lib"), Directory($"{packageLocationX64}/sdk/lib"));
    CopyDirectory(Directory($"./{artifactwin64}/{nightlyVersion}/sdk/include"), Directory($"{packageLocationX64}/sdk/include"));
}

void CreateNuGetPackage()
{
    PrepareForPackaging();

    Console.WriteLine("Version for package: " + packageVersionWin64);
    NuGetPack("../VideoLAN.LibVLC.Windows.nuspec", new NuGetPackSettings
    {
        // package version URLs differ from the same nightly build depending on the arch.
        // using the number from win64
        Version = $"4.0.0-alpha-{packageVersionWin64}"
    });
}

static List<string> ExtractLinks(string html)
{
    List<string> list = new List<string>();

    Regex regex = new Regex("(?:href|src)=[\"|']?(.*?)[\"|'|>]+", RegexOptions.Singleline | RegexOptions.CultureInvariant);
    if (regex.IsMatch(html))
    {
        foreach (Match match in regex.Matches(html))
        {
            list.Add(match.Groups[1].Value);
        }
    }

    return list;
}

//////////////////////////////////////////////////////////////////////
// TASK TARGETS
//////////////////////////////////////////////////////////////////////

Task("Default")
    .IsDependentOn("Publish");

//////////////////////////////////////////////////////////////////////
// EXECUTION
//////////////////////////////////////////////////////////////////////

RunTarget(target);
