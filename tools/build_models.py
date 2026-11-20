#!/usr/bin/env python3
"""Extract the two static GLB tripods as Source SMDs with procedural leg bones.

Requires Python 3 only. Run from the repository root. Compile the emitted QC with
Garry's Mod's studiomdl (Source SDK / Crowbar); see README.md.
"""
import base64
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'generated' / 'source_models'
SCALE = 0.12
# Sketchfab scene has two copies, centred on x ~950 and x ~2850.
CENTERS = ((950, 850), (2850, 850))
# The low flat foundation is not part of either walking machine.
SKIP_MESHES = {0, 2, 3}
BONES = [('root', -1), ('leg_a', 0), ('leg_b', 0), ('leg_c', 0)]


def accessor(data, binary, index):
    a = data['accessors'][index]
    view = data['bufferViews'][a['bufferView']]
    fmt = {5126: 'f', 5125: 'I', 5123: 'H', 5121: 'B'}[a['componentType']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    step = view.get('byteStride', struct.calcsize('<' + fmt * n))
    start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    unpack = struct.Struct('<' + fmt * n).unpack_from
    return [unpack(binary, start + i * step) for i in range(a['count'])]


def vmt_color(m):
    rgba = m.get('pbrMetallicRoughness', {}).get('baseColorFactor', [0.7, 0.7, 0.7, 1])
    return '[' + ' '.join(f'{max(0.02, c):.4f}' for c in rgba[:3]) + ']'


def skeleton(f, frame, walking=False):
    f.write('skeleton\ntime %d\n' % frame)
    f.write('0 0 0 0 0 0 0\n')
    for j in range(1, 4):
        angle = math.sin(frame * math.pi / 8 + (j - 1) * 2 * math.pi / 3) * 0.13 if walking else 0
        f.write(f'{j} 0 0 175 {angle:.6f} 0 0\n')
    f.write('end\n')


def write_animation(name, walking):
    with (OUT / f'{name}.smd').open('w') as f:
        f.write('version 1\nnodes\n')
        for i, (bone, parent) in enumerate(BONES):
            f.write(f'{i} "{bone}" {parent}\n')
        f.write('end\n')
        for frame in range(16 if walking else 1):
            skeleton(f, frame, walking)


def main():
    with (ROOT / 'tripods_the_tripods_1984.glb').open('rb') as f:
        magic, version, length = struct.unpack('<4sII', f.read(12))
        assert magic == b'glTF' and version == 2
        size, chunk = struct.unpack('<I4s', f.read(8))
        assert chunk == b'JSON'
        data = json.loads(f.read(size))
        size, chunk = struct.unpack('<I4s', f.read(8))
        assert chunk == b'BIN\x00'
        binary = f.read(size)
    OUT.mkdir(parents=True, exist_ok=True)
    materials = ROOT / 'materials/models/wow_tripods'
    materials.mkdir(parents=True, exist_ok=True)
    for i, mat in enumerate(data['materials']):
        # debugwhite is supplied by Source; colour tint preserves GLB material palette.
        (materials / f'mat_{i:02}.vmt').write_text(
            '"VertexLitGeneric"\n{\n "$basetexture" "models/debug/debugwhite"\n'
            f' "$color2" "{vmt_color(mat)}"\n "$model" "1"\n}}\n')
    # Vertex-colored runtime geometry allows GMod to display the *actual* GLB
    # without studiomdl. Chunk it so no single IMesh exceeds common limits.
    runtime_dir = ROOT / 'lua/wow_tripods_mesh'
    runtime_dir.mkdir(parents=True, exist_ok=True)
    for old in runtime_dir.glob('*.lua'):
        old.unlink()
    runtime = [[[] for _ in range(4)] for _ in range(2)]
    runtime_chunks = [[[] for _ in range(4)] for _ in range(2)]
    runtime_counts = [[0 for _ in range(4)] for _ in range(2)]
    (materials / 'runtime.vmt').write_text(
        '"UnlitGeneric"\n{\n "$basetexture" "models/debug/debugwhite"\n'
        ' "$vertexcolor" "1"\n "$nocull" "1"\n}\n')

    def flush(side, bone):
        if not runtime_counts[side][bone]:
            return
        payload = base64.b64encode(b''.join(runtime[side][bone])).decode('ascii')
        name = f'{("white", "red")[side]}_{bone}_{len(runtime_chunks[side][bone])}.lua'
        (runtime_dir / name).write_text(f'return {{{bone}, {runtime_counts[side][bone]}, "{payload}"}}\n')
        runtime_chunks[side][bone].append(name)
        runtime[side][bone].clear()
        runtime_counts[side][bone] = 0

    write_animation('idle', False)
    write_animation('walk', True)
    files = [(OUT / f'tripod_{i}.smd').open('w') for i in range(2)]
    try:
        for f in files:
            f.write('version 1\nnodes\n')
            for j, (bone, parent) in enumerate(BONES):
                f.write(f'{j} "{bone}" {parent}\n')
            f.write('end\n')
            skeleton(f, 0)
            f.write('triangles\n')
        triangles = [0, 0]
        for mesh_id, mesh in enumerate(data['meshes']):
            if mesh_id in SKIP_MESHES:
                continue
            p = mesh['primitives'][0]
            if p.get('mode', 4) != 4:
                continue  # SketchUp's non-rendered wireframe edges
            attrs = p['attributes']
            pos = accessor(data, binary, attrs['POSITION'])
            normals = accessor(data, binary, attrs['NORMAL']) if 'NORMAL' in attrs else None
            uv = accessor(data, binary, attrs['TEXCOORD_0']) if 'TEXCOORD_0' in attrs else None
            indices = [a[0] for a in accessor(data, binary, p['indices'])]
            for k in range(0, len(indices), 3):
                ids = indices[k:k + 3]
                if len(ids) != 3:
                    continue
                verts = [pos[q] for q in ids]
                x = sum(v[0] for v in verts) / 3
                side = int(x >= 1900)
                cx, cy = CENTERS[side]
                # Ignore loose scenery: only geometry belonging to each tripod.
                if any(abs(v[0] - cx) > 970 for v in verts):
                    continue
                out = files[side]
                out.write(f'mat_{p["material"]:02}\n')
                triangles[side] += 1
                avgz = sum(v[2] for v in verts) * SCALE / 3
                theta = math.atan2(sum(v[1] for v in verts) / 3 - cy, x - cx)
                group = 1 + int(((theta + math.pi) / (2 * math.pi) * 3) % 3) if avgz < 175 else 0
                rgb = data['materials'][p['material']].get('pbrMetallicRoughness', {}).get('baseColorFactor', [0.7, 0.7, 0.7])
                tint = (0.94, 0.97, 1) if side == 0 else (1, 0.60, 0.60)
                packed = bytearray(max(6, min(255, round(rgb[c] * tint[c] * 255))) for c in range(3))
                for idx, v in zip(ids, verts):
                    px, py, pz = (v[0] - cx) * SCALE, (v[1] - cy) * SCALE, v[2] * SCALE
                    # Rigid leg groups pivot around the head, not around their feet.
                    # Only lower geometry is animated; canopy stays on the root.
                    if pz < 175:
                        theta = math.atan2(py, px)
                        bone = 1 + int(((theta + math.pi) / (2 * math.pi) * 3) % 3)
                    else:
                        bone = 0
                    nx, ny, nz = normals[idx] if normals else (0, 0, 1)
                    u, vv = uv[idx] if uv else (0, 0)
                    out.write(f'{bone} {-py:.5f} {px:.5f} {pz - (175 if bone else 0):.5f} {-ny:.5f} {nx:.5f} {nz:.5f} {u:.5f} {1-vv:.5f}\n')
                    packed.extend(struct.pack('<hhhbbb',
                        round(px * 100), round(py * 100), round((pz - (175 if group else 0)) * 100),
                        *(max(-127, min(127, round(n * 127))) for n in (nx, ny, nz))))
                runtime[side][group].append(bytes(packed))
                runtime_counts[side][group] += 1
                if runtime_counts[side][group] >= 5000:
                    flush(side, group)
        for f in files:
            f.write('end\n')
        for side in range(2):
            for bone in range(4):
                flush(side, bone)
        geometry = ROOT / 'lua/wow_tripods_geometry.lua'
        geometry.parent.mkdir(parents=True, exist_ok=True)
        with geometry.open('w') as f:
            f.write('-- Generated from tripods_the_tripods_1984.glb by tools/build_models.py.\nreturn {\n')
            for side, name in enumerate(('white', 'red')):
                f.write(f'  {name} = {{\n')
                for bone, chunks in enumerate(runtime_chunks[side]):
                    for name in chunks:
                        f.write(f'    include("wow_tripods_mesh/{name}"),\n')
                f.write('  },\n')
            f.write('}\n')
        print('Exported triangles:', triangles, 'runtime chunks:', sum(len(x) for side in runtime_chunks for x in side))
    finally:
        for f in files:
            f.close()
    for kind, i in (('red', 1), ('white', 0)):
        (OUT / f'tripod_{kind}.qc').write_text(
            f'$modelname "wow_tripods/tripod_{kind}.mdl"\n'
            f'$body "body" "tripod_{i}.smd"\n'
            '$cdmaterials "models/wow_tripods/"\n'
            '$surfaceprop "metal"\n'
            '$sequence "idle" "idle.smd" fps 15 loop\n'
            '$sequence "walk" "walk.smd" fps 15 loop\n'
            '$bbox -105 -105 0 105 105 290\n'
            '$cbox -105 -105 0 105 105 290\n')
    print('Source files:', OUT)
    print('Compile both tripod_*.qc using studiomdl; install resulting .mdl/.vtx/.vvd into models/wow_tripods/.')


if __name__ == '__main__':
    main()
