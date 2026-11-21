#!/usr/bin/env python3
"""Flatten the two supplied glTF scenes into client IMesh chunks with animation groups.

No external dependencies or studiomdl. Original files stay untouched and are
attributed in README. Static 1953 legs and the Spider's 98-bone, unanimated skin
are procedurally grouped; no original animation clips exist in either asset.
"""
import base64
import json
import math
import struct
from pathlib import Path

from build_models import accessor

ROOT = Path(__file__).resolve().parent.parent
CHUNKS = ROOT / 'lua/wow_tripods_mesh'
INDEX = ROOT / 'lua/wotw_new_geometry.lua'
SCALE = 32
MAX_TRIANGLES = 4500
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
CONFIG = {
    '1953': ('1953_tripod.glb', 3, 3.2),
    'spider': ('martian_spider.glb', 4, 4.0),
}


def multiply(a, b):
    # glTF column-major matrices
    return [sum(a[k*4+r]*b[c*4+k] for k in range(4)) for c in range(4) for r in range(4)]


def matrix(node):
    if 'matrix' in node:
        return node['matrix']
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    sx, sy, sz = node.get('scale', [1, 1, 1])
    tx, ty, tz = node.get('translation', [0, 0, 0])
    return [
        (1 - 2*(y*y+z*z))*sx, 2*(x*y+z*w)*sx, 2*(x*z-y*w)*sx, 0,
        2*(x*y-z*w)*sy, (1-2*(x*x+z*z))*sy, 2*(y*z+x*w)*sy, 0,
        2*(x*z+y*w)*sz, 2*(y*z-x*w)*sz, (1-2*(x*x+y*y))*sz, 0,
        tx, ty, tz, 1,
    ]


def transform(m, p):
    return tuple(sum(m[c*4+r]*p[c] for c in range(3))+m[12+r] for r in range(3))


def load(name):
    with (ROOT / name).open('rb') as f:
        magic, version, length = struct.unpack('<4sII', f.read(12))
        if magic != b'glTF' or version != 2:
            raise ValueError('Expected glTF 2.0: '+name)
        n, tag = struct.unpack('<I4s', f.read(8))
        if tag != b'JSON':
            raise ValueError('Missing JSON chunk')
        data = json.loads(f.read(n))
        n, tag = struct.unpack('<I4s', f.read(8))
        if tag != b'BIN\0':
            raise ValueError('Missing BIN chunk')
        binary = f.read(n)
    if data.get('animations'):
        raise ValueError('Asset now has real animation; inspect before replacing it')
    return data, binary


def mesh_nodes(data):
    def walk(node_id, parent):
        node = data['nodes'][node_id]
        world = multiply(parent, matrix(node))
        if 'mesh' in node:
            yield node['mesh'], world
        for child in node.get('children', []):
            yield from walk(child, world)
    for root in data['scenes'][data.get('scene', 0)]['nodes']:
        yield from walk(root, IDENTITY)


def normal(p0, p1, p2):
    a = tuple(p1[j]-p0[j] for j in range(3))
    b = tuple(p2[j]-p0[j] for j in range(3))
    v = (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
    length = math.sqrt(sum(c*c for c in v))
    return tuple(c/length for c in v) if length > 1e-9 else (0, 0, 1)


def process(kind, filename, leg_count, leg_pivot):
    data, binary = load(filename)
    sources = []
    limits = [[math.inf]*3, [-math.inf]*3]
    for mesh_id, world in mesh_nodes(data):
        for primitive in data['meshes'][mesh_id]['primitives']:
            if primitive.get('mode', 4) != 4:
                continue
            positions = [transform(world, p) for p in accessor(data, binary, primitive['attributes']['POSITION'])]
            for p in positions:
                for axis in range(3):
                    limits[0][axis] = min(limits[0][axis], p[axis])
                    limits[1][axis] = max(limits[1][axis], p[axis])
            indices = ([t[0] for t in accessor(data, binary, primitive['indices'])]
                       if 'indices' in primitive else list(range(len(positions))))
            sources.append((positions, indices, primitive.get('material', 0)))
    centerx = (limits[0][0]+limits[1][0])/2
    centerz = (limits[0][2]+limits[1][2])/2
    floor = limits[0][1]
    pivot = (leg_pivot-floor)*SCALE
    CHUNKS.mkdir(parents=True, exist_ok=True)
    for old in CHUNKS.glob(kind+'_*.lua'):
        old.unlink()
    groups = [[] for _ in range(leg_count+1)]
    count = [0]*(leg_count+1)
    names = [[] for _ in range(leg_count+1)]

    def flush(group):
        if not count[group]:
            return
        name = f'{kind}_{group}_{len(names[group])}.lua'
        encoded = base64.b64encode(b''.join(groups[group])).decode('ascii')
        (CHUNKS / name).write_text(f'return {{{group}, {count[group]}, "{encoded}"}}\n')
        names[group].append(name)
        groups[group].clear()
        count[group] = 0

    triangles = 0
    for positions, indices, material_id in sources:
        mat = data['materials'][material_id]
        rgba = mat.get('pbrMetallicRoughness', {}).get('baseColorFactor', [0.65, 0.65, 0.65, 1])
        rgb = bytes(max(8, min(255, round(c*255))) for c in rgba[:3])
        for offset in range(0, len(indices)-2, 3):
            p = [positions[indices[offset+j]] for j in range(3)]
            avg = tuple(sum(v[i] for v in p)/3 for i in range(3))
            r = math.hypot(avg[0]-centerx, avg[2]-centerz)
            group = 0
            # Low, outer limbs are animated. The hull/head stays rigid.
            if avg[1] < leg_pivot and r > (0.9 if kind == '1953' else 0.45):
                angle = math.atan2(avg[2]-centerz, avg[0]-centerx)
                group = 1 + int(((angle+math.pi)/(2*math.pi)*leg_count) % leg_count)
            vertices = [((v[0]-centerx)*SCALE, -(v[2]-centerz)*SCALE,
                         (v[1]-floor)*SCALE - (pivot if group else 0)) for v in p]
            n = normal(*vertices)
            packed = bytearray(rgb)
            for v in vertices:
                packed.extend(struct.pack('<hhhbbb',
                    *(round(c*100) for c in v),
                    *(max(-127, min(127, round(c*127))) for c in n)))
            groups[group].append(bytes(packed))
            count[group] += 1
            triangles += 1
            if count[group] >= MAX_TRIANGLES:
                flush(group)
    for group in range(leg_count+1):
        flush(group)
    print(f'{kind}: {triangles} triangles, {sum(map(len,names))} chunks, '
          f'bounding {limits[0]}..{limits[1]}, leg pivot {pivot:.1f} units')
    return names, pivot, triangles


def main():
    assets = {kind: process(kind, *config) for kind, config in CONFIG.items()}
    with INDEX.open('w') as f:
        f.write('-- Generated by tools/build_new_models.py from supplied CC-BY GLB files.\nreturn {\n')
        for kind, (groups, pivot, triangles) in assets.items():
            f.write(f'  ["{kind}"] = {{ pivot = {pivot:.5f}, chunks = {{\n')
            for names in groups:
                for name in names:
                    f.write(f'    include("wow_tripods_mesh/{name}"),\n')
            f.write('  }},\n')
        f.write('}\n')


if __name__ == '__main__':
    main()
