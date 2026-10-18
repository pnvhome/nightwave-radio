#!/usr/bin/env python3
import pathlib, re, subprocess, sys
binary = pathlib.Path(sys.argv[1])
for line in subprocess.check_output(['otool', '-L', str(binary)], text=True).splitlines()[1:]:
    dependency = line.strip().split(' (compatibility')[0]
    name = pathlib.Path(dependency).name
    for library in ['mlx', 'mlxc', 'llama', 'webp', 'sharpyuv', 'jaccl']:
        if re.fullmatch(r'lib' + library + r'(?:\.[0-9]+)*\.dylib', name):
            target = '@executable_path/../Frameworks/lib' + library + '.dylib'
            if dependency != target: subprocess.run(['install_name_tool', '-change', dependency, target, str(binary)], check=True)
