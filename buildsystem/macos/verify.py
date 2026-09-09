"""Check a staged or unpacked macOS runtime without loading it."""
import hashlib
import json
from pathlib import Path
import sys
from stage import dependencies, is_system, run


def verify(root, rid):
    arch = {"osx-x64": "x86_64", "osx-arm64": "arm64"}[rid]
    root = root.resolve()
    manifest = json.loads((root / "build-manifest.json").read_text())
    assert manifest["rid"] == rid and manifest["architecture"] == arch
    assert not manifest["contrib"]["GPL"]
    if "freetype2" in manifest["contrib"]["PKGS"].split():
        assert manifest["contrib"]["AD_CLAUSES"], "FreeType FTL was not selected"
        for name in ("docs/FTL.TXT", "LICENSE.TXT", "NOTICE.txt"):
            assert (root / "licenses/freetype2" / name).is_file(), name
    actual = {str(p.relative_to(root)) for p in root.rglob("*")
              if p.is_file() and p != root / "build-manifest.json"}
    assert actual == set(manifest["files"]), "Unexpected or missing files in runtime tree"
    for name, digest in manifest["files"].items():
        path = root / name
        assert path.is_file() and not path.is_symlink(), name
        assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, name
    for path in root.rglob("*.dylib"):
        assert run("lipo", "-archs", str(path)) == arch, path
        run("codesign", "--verify", "--strict", str(path))
        for dep in dependencies(path):
            if is_system(dep):
                continue
            assert dep.startswith("@loader_path/"), (path, dep)
            resolved = (path.parent / dep.removeprefix("@loader_path/")).resolve()
            assert resolved.is_relative_to(root) and resolved.is_file(), (path, dep)
    print(f"Verified {rid}: {len(manifest['plugins'])} plugins")


if __name__ == "__main__":
    verify(Path(sys.argv[1]), sys.argv[2])
