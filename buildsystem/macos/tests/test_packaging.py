import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from stage import dependencies, freetype_notices, is_system, source_license


class PolicyTests(unittest.TestCase):
    def test_versions_match_nuspec(self):
        versions = json.loads((HERE / "versions.json").read_text())
        spec = ET.parse(ROOT / "VideoLAN.LibVLC.Mac.nuspec").getroot()
        self.assertEqual(spec.findtext("metadata/version"), versions["package_version"])
        self.assertEqual(spec.findtext("metadata/license"), "LGPL-3.0-or-later")
        self.assertRegex(versions["vlc_commit"], r"^[0-9a-f]{40}$")
        policy = json.loads((HERE / "plugins.json").read_text())
        self.assertFalse(set(policy["required"]) & set(policy["optional"]))
        self.assertFalse(set(policy["required"] + policy["optional"]) &
                         {"macosx", "dummy", "logger", "file_logger", "stats", "headphone_channel_mixer", "x264"})

    def test_license_audit_rejects_gpl_and_unknown_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "codec.c"
            path.write_text("GNU Lesser General Public License version 3")
            self.assertIn("LGPL", source_license(path))
            for notice in ("GNU General Public License version 3", "All rights reserved"):
                path.write_text(notice)
                with self.assertRaises(ValueError):
                    source_license(path)

    def test_dependency_parser_excludes_identity_but_keeps_host_dependency(self):
        def otool(*args, **kwargs):
            if args[1] == "-D":
                return "libvlc.dylib:\n@rpath/libvlc.5.dylib"
            return ("libvlc.dylib:\n\t@rpath/libvlc.5.dylib (compatibility version 1.0.0, current version 1.0.0)\n"
                    "\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1.0.0)\n"
                    "\t/opt/homebrew/lib/libbad.dylib (compatibility version 1.0.0, current version 1.0.0)")
        with patch("stage.run", side_effect=otool):
            deps = dependencies(Path("libvlc.dylib"))
        self.assertEqual(len(deps), 2)
        self.assertTrue(is_system(deps[0]))
        self.assertFalse(is_system(deps[1]))

    def test_freetype_requires_ftl_and_preserves_nested_notices(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            values = {"PKGS": "freetype2 zlib", "GPL": "", "AD_CLAUSES": "1"}
            for override in ({"GPL": "1"}, {"AD_CLAUSES": ""}):
                with self.assertRaises(ValueError):
                    freetype_notices(root, root / "notices", {**values, **override})
            # Missing license sources must fail rather than silently omit notices.
            with self.assertRaises(FileNotFoundError):
                freetype_notices(root, root / "notices", values)
            files = ("LICENSE.TXT", "docs/FTL.TXT", "src/bdf/README", "src/pcf/README",
                     "src/base/fthash.c", "include/freetype/internal/fthash.h",
                     "src/gzip/zlib.h", "src/autofit/ft-hb.c", "src/autofit/ft-hb.h")
            for name in files:
                path = root / "freetype" / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(("Original notice: " + name + "\r\n").encode())
            freetype_notices(root, root / "notices", values)
            for name in files:
                self.assertEqual((root / "freetype" / name).read_bytes(),
                                 (root / "notices/freetype2" / name).read_bytes())
            self.assertIn("FreeType Team", (root / "notices/freetype2/NOTICE.txt").read_text())


@unittest.skipUnless(shutil.which("dotnet"), "MSBuild requires dotnet")
class TargetTests(unittest.TestCase):
    def test_rid_selection_preserves_hierarchy_and_transitive_imports(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for folder in ("build", "buildTransitive"):
                (root / folder).mkdir()
                shutil.copy2(ROOT / "build/VideoLAN.LibVLC.Mac.targets", root / folder / "VideoLAN.LibVLC.Mac.targets")
            for rid in ("osx-x64", "osx-arm64"):
                for name in ("lib/libvlc.dylib", "lib/vlc/plugins/codec/libavcodec_plugin.dylib", "lib/vlc/share/test.txt"):
                    path = root / "build/macos" / rid / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(rid)
            project = root / "consumer.proj"
            project.write_text('<Project><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup>'
                               '<Import Project="build/VideoLAN.LibVLC.Mac.targets"/>'
                               '<Import Project="buildTransitive/VideoLAN.LibVLC.Mac.targets"/></Project>')
            for rid, expected in (("", {"osx-x64", "osx-arm64"}), ("osx-x64", {"osx-x64"}),
                                  ("osx-arm64", {"osx-arm64"}), ("win-x64", set())):
                with self.subTest(rid=rid):
                    output = subprocess.check_output(["dotnet", "msbuild", str(project), "-nologo",
                                                      "-getItem:Content", f"-p:RuntimeIdentifier={rid}"], text=True)
                    data = json.loads(output[output.index("{"):])["Items"]["Content"]
                    links = [item["Link"].replace("\\", "/") for item in data]
                    self.assertEqual(len(links), 3 * len(expected))
                    self.assertEqual(len(set(links)), len(links))
                    self.assertEqual({link.split("/")[1] for link in links}, expected)
                    for item in data:
                        self.assertEqual(item["CopyToPublishDirectory"], "PreserveNewest")
                    for selected in expected:
                        self.assertIn(f"libvlc/{selected}/lib/vlc/plugins/codec/libavcodec_plugin.dylib", links)
            # The Apple SDK must preserve the complete tree next to the managed
            # assemblies, not turn dylibs into flattened native references.
            for rid in ("osx-x64", "osx-arm64"):
                output = subprocess.check_output([
                    "dotnet", "msbuild", str(project), "-nologo", "-getItem:Content",
                    "-p:TargetFramework=net8.0-macos", f"-p:RuntimeIdentifier={rid}"], text=True)
                data = json.loads(output[output.index("{"):])["Items"]["Content"]
                self.assertEqual(len(data), 3)
                for item in data:
                    self.assertEqual(item["Identity"], item["FullPath"])
                    self.assertEqual(item["PublishFolderType"], "Assembly")
                    self.assertTrue(item["Link"].replace("\\", "/").startswith(f"libvlc/{rid}/"))
            # A RID switch in a reused output directory must remove the other
            # runtime and obsolete plugins, while retaining unrelated app files.
            for kind, target, prop in (("build-out", "PruneVlcMacBuildOutput", "OutDir"),
                                       ("publish-out", "PruneVlcMacPublishOutput", "PublishDir")):
                output = root / kind
                for name in ("libvlc/osx-x64/lib/libvlc.dylib", "libvlc/osx-x64/lib/obsolete.dylib",
                             "libvlc/osx-arm64/lib/libvlc.dylib", "app-data.txt"):
                    path = output / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text("keep or remove")
                subprocess.check_call(["dotnet", "msbuild", str(project), "-nologo", "-v:quiet",
                                       f"-t:{target}", "-p:RuntimeIdentifier=osx-x64", f"-p:{prop}={output}{os.sep}"])
                self.assertTrue((output / "libvlc/osx-x64/lib/libvlc.dylib").exists())
                self.assertFalse((output / "libvlc/osx-x64/lib/obsolete.dylib").exists())
                self.assertFalse((output / "libvlc/osx-arm64").exists())
                self.assertTrue((output / "app-data.txt").exists())


if __name__ == "__main__":
    unittest.main()
