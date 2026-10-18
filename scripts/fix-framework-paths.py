#!/usr/bin/env python3
"""Resolve all bundled library references relative to the referring library."""
import pathlib, subprocess
folder = pathlib.Path(__import__('sys').argv[1])
for binary in folder.glob('*.dylib'):
    subprocess.run(['install_name_tool', '-id', '@rpath/' + binary.name, str(binary)], check=True)
    lines = subprocess.check_output(['otool', '-L', str(binary)], text=True).splitlines()[2:]
    for line in lines:
        dependency = line.strip().split(' (compatibility')[0]
        name = pathlib.Path(dependency).name
        if (folder / name).exists():
            subprocess.run(['install_name_tool', '-change', dependency, '@loader_path/' + name, str(binary)], check=True)
