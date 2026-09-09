"""Stage the shared VLC install without trusting host libraries or symlinks."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent


def run(*args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def make_values(directory, variables):
    # Let make expand the actual generated Makefile, including conditional
    # sources and convenience libraries. Do not guess from Makefile.am text.
    with tempfile.NamedTemporaryFile(mode="w", suffix=".mk", delete=False) as f:
        for name in variables:
            f.write(f"$(info MACOS_AUDIT:{name}=$({name}))\n")
        f.write(".PHONY: macos-source-audit\nmacos-source-audit:\n\t@:\n")
    try:
        output = run("make", "--no-print-directory", "-s", "-f", "Makefile", "-f", f.name,
                     "macos-source-audit", cwd=directory)
    finally:
        os.unlink(f.name)
    return dict(line.removeprefix("MACOS_AUDIT:").split("=", 1)
                for line in output.splitlines() if line.startswith("MACOS_AUDIT:"))


def source_license(path):
    text = path.read_text(errors="replace")[:16000].lower()
    if "lesser general public license" in text or "library general public license" in text:
        return "LGPL (see source notice)"
    if "general public license" in text:
        raise ValueError(f"GPL source in selected module: {path}")
    if "permission is hereby granted" in text:
        return "MIT-style (see source notice)"
    if "redistribution and use in source and binary" in text:
        return "BSD-style (see source notice)"
    if "public domain" in text:
        return "Public domain (see source notice)"
    if path.name == "dummy.cpp" and not text.strip():
        return "Empty generated translation unit"
    raise ValueError(f"Unrecognized source license; review before shipping: {path}")


def module_sources(source, modules_build, names):
    prefixes = [f"lib{name}_plugin_la" for name in names]
    # Include sources in locally linked convenience libraries as well.
    result = {}
    pending = prefixes[:]
    seen = set()
    while pending:
        current = sorted(set(pending) - seen)
        if not current:
            break
        seen.update(current)
        values = make_values(modules_build, [p + suffix for p in current
                                             for suffix in ("_SOURCES", "_LIBADD")])
        pending = []
        for prefix in current:
            sources = values[prefix + "_SOURCES"].split()
            if not sources:
                raise ValueError(f"No auditable sources for {prefix}")
            notices = {}
            for name in sources:
                if Path(name).suffix not in (".c", ".cpp", ".cc", ".m", ".mm", ".S", ".s"):
                    continue
                path = source / "modules" / name
                if not path.exists():
                    path = modules_build / name
                notices[name] = source_license(path)
            result[prefix] = notices
            for lib in values[prefix + "_LIBADD"].split():
                # Core/compat are audited separately; system/contrib -l flags
                # are governed by the pinned contrib configuration.
                if lib.endswith(".la") and not lib.startswith("../"):
                    pending.append(Path(lib).name.replace(".", "_").replace("-", "_"))
    return result


def dylib_id(path):
    lines = run("otool", "-D", str(path)).splitlines()
    return lines[1].strip() if len(lines) > 1 else None


def dependencies(path):
    identity = dylib_id(path)
    return [line.strip().split(" (compatibility version", 1)[0]
            for line in run("otool", "-L", str(path)).splitlines()[1:]
            if line.strip().split(" (compatibility version", 1)[0] != identity]


def is_system(name):
    return name.startswith(("/usr/lib/", "/System/Library/"))


def freetype_notices(contrib_build, notices, contrib_values):
    if "freetype2" not in contrib_values["PKGS"].split():
        return
    if contrib_values["GPL"] or not contrib_values["AD_CLAUSES"]:
        raise ValueError("FreeType must use FTL with attribution and GPL disabled")
    # The contrib package is named freetype2, but its source directory is freetype.
    # LICENSE.TXT identifies additional permissive notices in these source files.
    source = contrib_build / "freetype"
    destination = notices / "freetype2"
    for name in ("LICENSE.TXT", "docs/FTL.TXT", "src/bdf/README", "src/pcf/README",
                 "src/base/fthash.c", "include/freetype/internal/fthash.h",
                 "src/gzip/zlib.h", "src/autofit/ft-hb.c", "src/autofit/ft-hb.h"):
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / name, target)
    (destination / "NOTICE.txt").write_text(
        "This software is based in part on the work of the FreeType Team "
        "(https://freetype.org/).\n"
        "FreeType is used under the FreeType Project License (FTL). "
        "See docs/FTL.TXT and LICENSE.TXT for the license and additional notices.\n",
        encoding="utf-8")


def stage(source, rid, destination):
    arch = {"osx-x64": "x86_64", "osx-arm64": "arm64"}[rid]
    build = source / "nuget-build"
    installed = build / f"vlc-macosx-{arch}"
    contrib = build / "contrib" / f"{arch}-macosx"
    if destination.exists():
        raise ValueError(f"Use a fresh staging directory: {destination}")
    policy = json.loads((HERE / "plugins.json").read_text())
    plugins = {p.name.removeprefix("lib").removesuffix("_plugin.dylib"): p
               for p in (installed / "lib/vlc/plugins").rglob("*_plugin.dylib")}
    missing = set(policy["required"]) - plugins.keys()
    if missing:
        raise ValueError(f"Required modules were not built: {sorted(missing)}")
    selected = sorted(plugins.keys() & set(policy["required"] + policy["optional"]))
    licenses = module_sources(source, build / "build/modules", selected)
    contrib_dirs = list((source / "contrib").glob("contrib-*/config.mak"))
    if len(contrib_dirs) != 1:
        raise ValueError("Expected one contrib build directory")
    contrib_values = make_values(contrib_dirs[0].parent, ["GPL", "GNUV3", "AD_CLAUSES", "PKGS", "PKGS_FOUND"])
    if contrib_values["GPL"]:
        raise ValueError("Contrib was built with GPL enabled")
    for name in ("lib/core.c", "src/libvlc.c", "compat/strdup.c"):
        source_license(source / name)

    library_dir = destination / "lib"
    library_dir.mkdir(parents=True)
    mapping = {}
    queue = []

    def copy_library(original, target):
        original = original.resolve(strict=True)
        if original in mapping:
            return mapping[original]
        if target.exists():
            raise ValueError(f"Library filename collision: {target}")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, target)
        mapping[original] = target
        queue.append(original)
        return target

    for name in ("libvlc.dylib", "libvlccore.dylib"):
        copy_library(installed / "lib" / name, library_dir / name)
    for name in selected:
        copy_library(plugins[name], library_dir / "vlc/plugins" /
                     plugins[name].relative_to(installed / "lib/vlc/plugins"))

    allowed_roots = [installed.resolve(), contrib.resolve()]
    for original in queue:
        target = mapping[original]
        changes = []
        for dep in dependencies(original):
            if is_system(dep):
                continue
            candidates = []
            if dep.startswith("@loader_path/"):
                candidates.append(original.parent / dep.removeprefix("@loader_path/"))
            elif dep.startswith("/"):
                candidates.append(Path(dep))
            elif dep.startswith("@rpath/"):
                candidates.extend(root / "lib" / Path(dep).name for root in allowed_roots)
            else:
                raise ValueError(f"Unsupported dependency {dep} in {original}")
            found = [p.resolve() for p in candidates if p.exists()
                     and any(p.resolve().is_relative_to(root) for root in allowed_roots)]
            if not found:
                raise ValueError(f"Non-system dependency outside the build: {dep} in {original}")
            resolved = found[0]
            dep_target = copy_library(resolved, library_dir / resolved.name)
            relative = os.path.relpath(dep_target, target.parent).replace(os.sep, "/")
            changes.extend(["-change", dep, "@loader_path/" + relative])
        # Remove signatures before changing load commands, and sign only the
        # finished binary. install_name_tool otherwise leaves invalid signatures.
        subprocess.run(["codesign", "--remove-signature", str(target)], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        run("install_name_tool", "-id", "@rpath/" + target.name, *changes, str(target))
        # Remove build-tree LC_RPATH entries; all bundled links are loader-relative.
        commands = run("otool", "-l", str(target))
        for rpath in re.findall(r"cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset", commands):
            run("install_name_tool", "-delete_rpath", rpath, str(target))
        run("codesign", "--force", "--sign", "-", str(target))

    data = installed / "share/vlc"
    if data.exists():
        shutil.copytree(data, library_dir / "vlc/share", symlinks=False)
    notices = destination / "licenses"
    notices.mkdir()
    for name in ("COPYING", "COPYING.LIB", "AUTHORS", "THANKS"):
        shutil.copy2(source / name, notices / name)
    # Preserve upstream dependency notices beside the explicit source bundle.
    for package in contrib_values["PKGS"].split():
        package_source = contrib_dirs[0].parent / package
        for pattern in ("COPYING*", "LICENSE*", "LICENCE*", "COPYRIGHT*", "Copyright*", "copyright*", "NOTICE*"):
            for notice in package_source.glob(pattern):
                if notice.is_file():
                    out = notices / package / notice.name
                    out.parent.mkdir(exist_ok=True)
                    shutil.copy2(notice, out)
    freetype_notices(contrib_dirs[0].parent, notices, contrib_values)
    manifest = {
        "versions": json.loads((HERE / "versions.json").read_text()),
        "rid": rid, "architecture": arch, "xcode": run("xcodebuild", "-version"),
        "sdk": run("xcrun", "--sdk", "macosx", "--show-sdk-version"),
        "runner_image": os.environ.get("ImageVersion", "local"),
        "plugins": selected, "excluded_plugins": sorted(plugins.keys() - set(selected)),
        "module_source_notices": licenses, "contrib": contrib_values,
        "packaging_inputs": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in sorted(HERE.iterdir()) if p.is_file()},
        "files": {str(p.relative_to(destination)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(destination.rglob("*")) if p.is_file()},
    }
    (destination / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    stage(Path(sys.argv[1]).resolve(), sys.argv[2], Path(sys.argv[3]).resolve())
