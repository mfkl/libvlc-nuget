"""Exercise the production relocation/signing path with real Mach-O libraries."""
import ctypes
from pathlib import Path
import platform
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stage import dependencies, is_system, relocate_library, run


@unittest.skipUnless(sys.platform == "darwin", "Requires Apple's compiler and signing tools")
class MachORelocationTests(unittest.TestCase):
    def test_signed_plugins_relocate_and_load_with_bundled_dependency(self):
        arch = platform.machine()
        self.assertIn(arch, ("x86_64", "arm64"))
        with tempfile.TemporaryDirectory(prefix="vlc-macho-") as tmp:
            root = Path(tmp)
            original = root / "original"
            original.mkdir()
            source = original / "sample.cpp"
            source.write_text('extern "C" int dependency() { return 42; }\n')
            dep = original / "libdependency.dylib"
            flags = ["-dynamiclib", "-arch", arch, "-mmacosx-version-min=11.0",
                     "-Wl,-headerpad_max_install_names"]
            run("xcrun", "clang++", *flags, str(source), "-o", str(dep),
                "-Wl,-install_name,@rpath/libdependency.dylib")
            run("codesign", "--force", "--sign", "-", str(dep))
            staged = root / "staged"
            libdir = staged / "lib"
            plugindir = libdir / "vlc/plugins/demux"
            plugindir.mkdir(parents=True)
            bundled_dep = libdir / dep.name
            shutil.copy2(dep, bundled_dep)
            relocate_library(bundled_dep, [])
            symbols = []
            # Vary symbol lengths to exercise different string-table padding.
            for length in range(1, 17):
                symbol = "probe_" + "x" * length
                symbols.append(symbol)
                source.write_text('extern "C" int dependency();\n'
                                  f'extern "C" int {symbol}() {{ return dependency() + 1; }}\n')
                plugin = original / f"libsample{length}_plugin.dylib"
                run("xcrun", "clang++", *flags, str(source), str(dep), "-o", str(plugin),
                    "-Wl,-install_name,@rpath/" + plugin.name, "-Wl,-rpath," + str(original))
                run("codesign", "--force", "--sign", "-", str(plugin))
                target = plugindir / plugin.name
                shutil.copy2(plugin, target)
                relocate_library(target, ["-change", "@rpath/libdependency.dylib",
                                          "@loader_path/../../../libdependency.dylib"])
                self.assertNotIn("cmd LC_RPATH", run("otool", "-l", str(target)))
                self.assertEqual([d for d in dependencies(target) if not is_system(d)],
                                 ["@loader_path/../../../libdependency.dylib"])
            relocated = root / "relocated"
            staged.rename(relocated)
            for path in relocated.rglob("*.dylib"):
                self.assertEqual(run("lipo", "-archs", str(path)), arch)
                run("codesign", "--verify", "--strict", str(path))
            for length, symbol in enumerate(symbols, 1):
                loaded = ctypes.CDLL(str(relocated / "lib/vlc/plugins/demux" /
                                         f"libsample{length}_plugin.dylib"))
                self.assertEqual(getattr(loaded, symbol)(), 43)


if __name__ == "__main__":
    unittest.main()
