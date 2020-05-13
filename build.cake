#tool nuget:?package=NUnit.ConsoleRunner&version=3.4.0
#addin nuget:?package=SevenZipExtractor&version=1.0.15

//////////////////////////////////////////////////////////////////////
// ARGUMENTS
//////////////////////////////////////////////////////////////////////

var target = Argument("target", "Default");
var configuration = Argument("configuration", "Release");

const string artifact = "artifact";

var artifactDir = Directory("./artifact");

var nightlyVersion = "vlc-4.0.0-dev";

var packageLocationX64 = Directory("./build/win7-x64/native");
string todayPartialLink = null;
const string ext = ".7z";

//////////////////////////////////////////////////////////////////////
// PREPARATION
//////////////////////////////////////////////////////////////////////

// Define directories.
var buildDir = Directory("./src/Example/bin") + Directory(configuration);

//////////////////////////////////////////////////////////////////////
// TASKS
//////////////////////////////////////////////////////////////////////

Task("Clean")
    .Does(() =>
{
    CleanDirectory(artifactDir);
    CleanDirectory(packageLocationX64);
    if(FileExists($"{artifact}.{ext}"))
        DeleteFile($"{artifact}.{ext}");
});


Task("Package-win64-nightly")
    .IsDependentOn("Clean")
    .Does(async () =>
{
    await DownloadArtifact();

    CreateNuGetPackage();
});

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using SevenZipExtractor;

// download and extract nightly build.
async Task DownloadArtifact()
{
    Console.WriteLine("Figuring out URL... ");
    const string baseUrl = "https://artifacts.videolan.org/vlc/nightly-";
    // const string win32 = "win32";
    const string win64 = "win64";
    string page;

    var today = DateTime.Today.ToString("yyyyMMdd");   

    var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
    HttpResponseMessage result;
    string url = null;

    url = $"{baseUrl}{win64}/";
    Console.WriteLine($"requesting {url}");
    result = await client.GetAsync(url);

    page = await result.Content.ReadAsStringAsync();
    todayPartialLink = ExtractLinks(page).Find(url => url.StartsWith(today));

    Console.WriteLine($"found partial link: {todayPartialLink}");

    url = $"{baseUrl}{win64}/{todayPartialLink}";
    Console.WriteLine($"requesting {url}");

    result = await client.GetAsync(url);
    page = await result.Content.ReadAsStringAsync();

    var todayLinkEnding = ExtractLinks(page).First(url => url.EndsWith(ext));
    if (todayLinkEnding == null) throw new NullReferenceException();

    client.Dispose();

    Console.WriteLine("Found the nightly artifact URL");

    using (var webClient = new WebClient())
    {
        url = $"{baseUrl}{win64}/{todayPartialLink}{todayLinkEnding}";
        Console.WriteLine($"requesting {url}");

        webClient.DownloadProgressChanged += (s, e) => Console.Write($"\r{e.ProgressPercentage}%");
        await webClient.DownloadFileTaskAsync(url, $"{artifact}.{ext}");
        Console.WriteLine("Done...");
    }
    
    Console.WriteLine("Extracting archive...");
    using (ArchiveFile archiveFile = new ArchiveFile($"{artifact}.{ext}"))
    {
        archiveFile.Extract($"./{artifact}");
    }
}

// move files in proper locations for nuget pack
void PrepareForPackaging()
{
    Console.WriteLine("PrepareForPackaging...");

    // TODO: per CPU
    var files = new []
    { 
        $"./{artifact}/{nightlyVersion}/libvlc.dll", 
        $"./{artifact}/{nightlyVersion}/libvlccore.dll" 
    };

    var directories = new [] 
    {
        Directory($"./{artifact}/{nightlyVersion}/hrtfs"),
        Directory($"./{artifact}/{nightlyVersion}/locale"),
        Directory($"./{artifact}/{nightlyVersion}/lua"),
        Directory($"./{artifact}/{nightlyVersion}/plugins"),
        Directory($"./{artifact}/{nightlyVersion}/sdk/lib"),
        Directory($"./{artifact}/{nightlyVersion}/sdk/include")
    };

    Console.WriteLine("Copying files for packaging... ");
    CopyFiles(files, packageLocationX64);

    CopyDirectory(Directory($"./{artifact}/{nightlyVersion}/hrtfs"), Directory($"{packageLocationX64}/hrtfs"));
    CopyDirectory(Directory($"./{artifact}/{nightlyVersion}/locale"), Directory($"{packageLocationX64}/locale"));
    CopyDirectory(Directory($"./{artifact}/{nightlyVersion}/lua"), Directory($"{packageLocationX64}/lua"));
    CopyDirectory(Directory($"./{artifact}/{nightlyVersion}/plugins"), Directory($"{packageLocationX64}/plugins"));
    CopyDirectory(Directory($"./{artifact}/{nightlyVersion}/sdk/lib"), Directory($"{packageLocationX64}/sdk/lib"));
    CopyDirectory(Directory($"./{artifact}/{nightlyVersion}/sdk/include"), Directory($"{packageLocationX64}/sdk/include"));
}

void CreateNuGetPackage()
{
    PrepareForPackaging();

    NuGetPack("./VideoLAN.LibVLC.Windows.nuspec", new NuGetPackSettings
    {
        Version = todayPartialLink.Trim('/').Replace('-', '.')
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
    .IsDependentOn("Package-win64-nightly");

//////////////////////////////////////////////////////////////////////
// EXECUTION
//////////////////////////////////////////////////////////////////////

RunTarget(target);
