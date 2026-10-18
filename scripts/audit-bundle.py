#!/usr/bin/env python3
"""Reject host-only dylibs, incompatible deployment targets and external symlinks."""
import json, pathlib, re, subprocess, sys
app = pathlib.Path(sys.argv[1]).resolve()
maximum = (26, 2, 0)
failures, binaries = [], []
magic = {bytes.fromhex(x) for x in ['cffaedfe', 'cefaedfe', 'cafebabe', 'bebafeca', 'cafebabf']}
for path in app.rglob('*'):
    if path.is_symlink():
        if not path.resolve().is_relative_to(app): failures.append(f'External symlink: {path}')
        continue
    if not path.is_file(): continue
    with path.open('rb') as stream: header = stream.read(4)
    if header not in magic: continue
    arch = subprocess.check_output(['lipo', '-archs', str(path)], text=True).strip()
    if 'arm64' not in arch.split(): failures.append(f'No arm64 slice: {path}: {arch}')
    build = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(path)], text=True)
    targets = re.findall(r'\bminos\s+([0-9.]+)', build)
    for value in targets:
        version = tuple((list(map(int, value.split('.'))) + [0, 0])[:3])
        if version > maximum: failures.append(f'Requires macOS {value}: {path}')
    dependencies = []
    for line in subprocess.check_output(['otool', '-L', str(path)], text=True).splitlines()[1:]:
        dependency = line.strip().split(' (compatibility')[0]
        dependencies.append(dependency)
        if path.suffix == '.dylib' and dependency == path.name: continue  # LC_ID_DYLIB, not a dependency
        if dependency.startswith(('/usr/lib/', '/System/Library/')): continue
        if dependency.startswith('/'):
            failures.append(f'External dependency: {path}: {dependency}')
            continue
        candidates = []
        if dependency.startswith('@loader_path/'):
            candidates = [path.parent / dependency[len('@loader_path/'):]]
        elif dependency.startswith('@executable_path/'):
            candidates = [app / 'Contents/MacOS' / dependency[len('@executable_path/'):], app / 'Contents/Resources/python/bin' / dependency[len('@executable_path/'):]]
        elif dependency.startswith('@rpath/'):
            name = dependency[len('@rpath/'):]
            candidates = [app / 'Contents/Frameworks' / name, path.parent / name, app / 'Contents/Resources/python/lib' / name]
        if not any(candidate.exists() and candidate.resolve().is_relative_to(app) for candidate in candidates):
            failures.append(f'Unresolved bundled dependency: {path}: {dependency}')
    binaries.append({'path': str(path.relative_to(app)), 'architectures': arch, 'minimum_macos': targets, 'dependencies': dependencies})
if failures:
    print('\n'.join(failures), file=sys.stderr)
    sys.exit(1)
print(json.dumps({'result': 'PASS', 'minimum_macos': '26.2', 'binaries': binaries}, indent=2))
