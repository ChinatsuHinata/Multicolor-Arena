"""Build Godot Android APK templates with the narrowly scoped replay VIEW activity.

Uses the installed SDK/JDK only. Stock template resource/string indices are preserved;
the additional activity is merged as compiled Android XML, not textual substitution.
"""
from __future__ import annotations
import argparse
import hashlib
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import zipfile

NO = 0xFFFFFFFF

def chunks(data: bytes):
    kind, header, size = struct.unpack_from('<HHI', data)
    if kind != 3 or header != 8 or size != len(data):
        raise ValueError('Invalid Android binary XML document')
    pos = header
    while pos < size:
        typ, head, length = struct.unpack_from('<HHI', data, pos)
        if head < 8 or length < head or pos + length > size:
            raise ValueError('Invalid Android XML chunk')
        yield typ, data[pos:pos + length]
        pos += length

def read_strings(chunk: bytes):
    count, styles, flags, start, _ = struct.unpack_from('<IIIII', chunk, 8)
    if styles:
        raise ValueError('Styled manifest string pools are unsupported')
    def length8(pos):
        first = chunk[pos]
        return (((first & 127) << 8) | chunk[pos + 1], pos + 2) if first & 128 else (first, pos + 1)
    def length16(pos):
        first, = struct.unpack_from('<H', chunk, pos)
        return (((first & 32767) << 16) | struct.unpack_from('<H', chunk, pos + 2)[0], pos + 4) if first & 32768 else (first, pos + 2)
    values = []
    for offset in struct.unpack_from('<' + 'I' * count, chunk, 28):
        pos = start + offset
        if flags & 256:
            _, pos = length8(pos)
            length, pos = length8(pos)
            values.append(chunk[pos:pos + length].decode('utf-8'))
        else:
            length, pos = length16(pos)
            values.append(chunk[pos:pos + length * 2].decode('utf-16le'))
    return values

def string_pool(values: list[str]):
    # Godot's standard Android exporter currently requires UTF-16 manifest pools.
    offsets, body = [], bytearray()
    def length(value):
        if value > 32767:
            return struct.pack('<HH', (value >> 16) | 32768, value & 65535)
        return struct.pack('<H', value)
    for value in values:
        offsets.append(len(body))
        encoded = value.encode('utf-16le')
        body.extend(length(len(encoded) // 2) + encoded + b'\0\0')
    body.extend(b'\0' * (-len(body) % 4))
    start = 28 + len(offsets) * 4
    return struct.pack('<HHIIIIII', 1, 28, start + len(body), len(values), 0, 0, start, 0) + struct.pack('<' + 'I' * len(offsets), *offsets) + body

def remap_node(chunk: bytes, mapping: dict[int, int]):
    out = bytearray(chunk)
    kind, = struct.unpack_from('<H', out)
    def index(pos):
        value, = struct.unpack_from('<I', out, pos)
        if value != NO: struct.pack_into('<I', out, pos, mapping[value])
    index(12)  # source comment
    if kind in (0x102, 0x103):
        index(16); index(20)
    if kind == 0x102:
        start, stride, count = struct.unpack_from('<HHH', out, 24)
        if stride != 20: raise ValueError('Unexpected Android XML attribute size')
        for pos in range(16 + start, 16 + start + stride * count, stride):
            index(pos); index(pos + 4); index(pos + 8)
            if out[pos + 15] == 3: index(pos + 16)
    elif kind != 0x103:
        raise ValueError('Unexpected node in replay activity')
    return bytes(out)

def merge_manifest(base: bytes, fragment: bytes):
    base_chunks, extra_chunks = list(chunks(base)), list(chunks(fragment))
    strings = read_strings(next(data for typ, data in base_chunks if typ == 1))
    extras = read_strings(next(data for typ, data in extra_chunks if typ == 1))
    names = {value: index for index, value in enumerate(strings)}
    mapping = {}
    for index, value in enumerate(extras):
        if value not in names:
            names[value] = len(strings); strings.append(value)
        mapping[index] = names[value]
    resources = []
    for typ, data in base_chunks:
        if typ == 0x180: resources = list(struct.unpack_from('<' + 'I' * ((len(data) - 8) // 4), data, 8))
    for typ, data in extra_chunks:
        if typ != 0x180: continue
        for index, resource in enumerate(struct.unpack_from('<' + 'I' * ((len(data) - 8) // 4), data, 8)):
            target = mapping[index]
            resources.extend([0] * (target + 1 - len(resources)))
            if resources[target] not in (0, resource): raise ValueError('Manifest resource ID conflict')
            resources[target] = resource
    activity, depth = [], 0
    for typ, data in extra_chunks:
        if typ == 0x102:
            name = extras[struct.unpack_from('<I', data, 20)[0]]
            if name == 'activity' and depth == 0: depth = 1
            elif depth: depth += 1
            if depth: activity.append(remap_node(data, mapping))
        elif typ == 0x103 and depth:
            activity.append(remap_node(data, mapping)); depth -= 1
    if not activity or depth: raise ValueError('Replay fragment activity is missing or unbalanced')
    if 'org.multicolorarena.replay.ReplayOpenActivity' in read_strings(next(data for typ, data in base_chunks if typ == 1)):
        raise ValueError('Stock template already has replay receiver')
    result, inserted = [], False
    for typ, data in base_chunks:
        if typ == 1:
            result.append(string_pool(strings))
            result.append(struct.pack('<HHI', 0x180, 8, 8 + 4 * len(resources)) + struct.pack('<' + 'I' * len(resources), *resources))
        elif typ == 0x180: continue
        else:
            if typ == 0x103 and strings[struct.unpack_from('<I', data, 20)[0]] == 'application':
                if inserted: raise ValueError('Multiple application elements')
                result.extend(activity); inserted = True
            result.append(data)
    if not inserted: raise ValueError('Stock template application element not found')
    body = b''.join(result)
    return struct.pack('<HHI', 3, 8, len(body) + 8) + body

def build_template(stock: Path, fragment: Path, dex: Path, destination: Path):
    with zipfile.ZipFile(stock) as original, zipfile.ZipFile(fragment) as extra:
        manifest = merge_manifest(original.read('AndroidManifest.xml'), extra.read('AndroidManifest.xml'))
        pool = next(data for typ, data in chunks(manifest) if typ == 1)
        if struct.unpack_from('<I', pool, 16)[0] & 256:
            raise ValueError('Godot Android export requires a UTF-16 manifest string pool')
        names = set(original.namelist())
        dex_index = 2
        while f'classes{dex_index}.dex' in names: dex_index += 1
        temporary = destination.with_suffix('.apk.tmp')
        with zipfile.ZipFile(temporary, 'w') as output:
            for entry in original.infolist():
                if entry.filename == 'AndroidManifest.xml': continue
                if entry.filename.upper().startswith('META-INF/') and re.search(r'(MANIFEST\.MF|\.(SF|RSA|DSA|EC))$', entry.filename.upper()): continue
                output.writestr(entry, original.read(entry.filename))
            output.writestr('AndroidManifest.xml', manifest, compress_type=zipfile.ZIP_DEFLATED)
            output.write(dex, f'classes{dex_index}.dex', compress_type=zipfile.ZIP_DEFLATED)
        temporary.replace(destination)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--jdk', type=Path, required=True)
    args = parser.parse_args()
    root, jdk = args.root.resolve(), args.jdk.resolve()
    sdk = root / '.godot-toolchain/android-sdk'
    build = sdk / 'build-tools/35.0.1'
    android = sdk / 'platforms/android-35/android.jar'
    stocks = root / '.godot-toolchain/editor/editor_data/export_templates/4.7.2.stable'
    out = root / '.godot-toolchain/android_replay'
    source = root / 'addons/android_replay'
    sources = sorted((source / 'native').rglob('*.java'))
    inputs = sources + [source / 'AndroidManifest.xml', Path(__file__), android] + [stocks / f'android_{mode}.apk' for mode in ('debug', 'release')]
    digest = hashlib.sha256()
    for path in inputs:
        with path.open('rb') as file:
            for block in iter(lambda: file.read(1024 * 1024), b''): digest.update(block)
    stamp = digest.hexdigest()
    out.mkdir(parents=True, exist_ok=True)
    stampfile = out / 'source.sha256'
    if stampfile.exists() and stampfile.read_text() == stamp and all((out / f'android_{mode}.apk').exists() for mode in ('debug', 'release')):
        print('Replay Android templates are up to date.'); return
    env = dict(os.environ, JAVA_HOME=str(jdk))
    env['PATH'] = str(jdk / 'bin') + os.pathsep + env.get('PATH', '')
    def run(command): subprocess.run([str(value) for value in command], check=True, env=env, cwd=root)
    with tempfile.TemporaryDirectory(prefix='replay-', dir=out) as directory:
        temp = Path(directory)
        classes, dexdir = temp / 'classes', temp / 'dex'
        classes.mkdir(); dexdir.mkdir()
        run([jdk / 'bin/javac.exe', '-encoding', 'UTF-8', '-source', '8', '-target', '8', '-Xlint:-options', '-classpath', android, '-d', classes, *sources])
        jar = temp / 'receiver.jar'
        run([jdk / 'bin/jar.exe', 'cf', jar, '-C', classes, '.'])
        run([build / 'd8.bat', '--min-api', '24', '--lib', android, '--output', dexdir, jar])
        fragment = temp / 'manifest.apk'
        # aapt's Windows ZIP reader cannot open non-ASCII absolute paths.
        run([build / 'aapt.exe', 'package', '-f', '-M', (source / 'AndroidManifest.xml').relative_to(root), '-I', android.relative_to(root), '-F', fragment.relative_to(root)])
        for mode in ('debug', 'release'):
            destination = out / f'android_{mode}.apk'
            build_template(stocks / destination.name, fragment, dexdir / 'classes.dex', destination)
            dump = subprocess.run([str(build / 'aapt.exe'), 'dump', 'xmltree', str(destination.relative_to(root)), 'AndroidManifest.xml'], check=True, capture_output=True, text=True, encoding='utf-8', errors='replace', cwd=root).stdout
            if 'org.multicolorarena.replay.ReplayOpenActivity' not in dump or 'android.intent.action.MAIN' not in dump:
                raise ValueError('Template manifest verification failed')
    stampfile.write_text(stamp)
    print('Built and checked replay Android debug/release templates.')

if __name__ == '__main__': main()
