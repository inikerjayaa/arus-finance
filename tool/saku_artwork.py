"""Read approved originals; render native launcher sizes without redrawing them.

Only generated native resources change dimensions. The committed originals are
hash-verified and never rewritten, cropped, recolored or traced.
"""
from pathlib import Path
import hashlib
import json
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
STACKED = 'assets/saku/stacked.png'


def verify_originals(root=ROOT):
    rows = json.loads((root / 'native_artwork/saku/provenance.json').read_text())['approved_originals']
    for row in rows:
        data = (root / row['path']).read_bytes()
        if hashlib.sha256(data).hexdigest() != row['sha256']:
            raise ValueError('Approved SAKU original changed: ' + row['path'])
        if struct.unpack('>II', data[16:24]) != (row['width'], row['height']):
            raise ValueError('Approved SAKU original dimensions changed')
    return rows


def read_rgb(path):
    """Decode the approved 8-bit, non-interlaced RGB PNG using stdlib only."""
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Expected approved PNG')
    width, height, depth, kind, compression, filtering, interlace = struct.unpack('>IIBBBBB', data[16:29])
    if (depth, kind, compression, filtering, interlace) != (8, 2, 0, 0, 0):
        raise ValueError('Expected original RGB8 non-interlaced artwork')
    payload = bytearray()
    pos = 8
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        if data[pos + 4:pos + 8] == b'IDAT':
            payload.extend(data[pos + 8:pos + 8 + length])
        pos += length + 12
    raw = zlib.decompress(payload)
    stride = width * 3
    if len(raw) != height * (stride + 1):
        raise ValueError('Invalid decoded PNG length')
    pixels = bytearray(height * stride)
    prior = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        row = bytearray(raw[start + 1:start + 1 + stride])
        if filter_type not in range(5):
            raise ValueError('Invalid PNG filter')
        if filter_type:
            for x in range(stride):
                left = row[x - 3] if x >= 3 else 0
                up = prior[x]
                corner = prior[x - 3] if x >= 3 else 0
                if filter_type == 1:
                    prediction = left
                elif filter_type == 2:
                    prediction = up
                elif filter_type == 3:
                    prediction = (left + up) // 2
                else:
                    p = left + up - corner
                    a, b, c = abs(p - left), abs(p - up), abs(p - corner)
                    prediction = left if a <= b and a <= c else up if b <= c else corner
                row[x] = (row[x] + prediction) & 255
        pixels[y * stride:(y + 1) * stride] = row
        prior = row
    return width, height, pixels


def launcher_pixels(source, size):
    """OS-size rendition of the entire source; never synthesize mark geometry."""
    width, height, pixels = source
    if width != height:
        raise ValueError('Launcher source must be the approved square original')
    output = bytearray(size * size * 3)
    coords = [min(width - 1, max(0, (i + .5) * width / size - .5)) for i in range(size)]
    for y, sy in enumerate(coords):
        y0 = int(sy); y1 = min(y0 + 1, height - 1); fy = sy - y0
        for x, sx in enumerate(coords):
            x0 = int(sx); x1 = min(x0 + 1, width - 1); fx = sx - x0
            a = (y0 * width + x0) * 3; b = (y0 * width + x1) * 3
            c = (y1 * width + x0) * 3; d = (y1 * width + x1) * 3
            out = (y * size + x) * 3
            for channel in range(3):
                top = pixels[a + channel] * (1 - fx) + pixels[b + channel] * fx
                bottom = pixels[c + channel] * (1 - fx) + pixels[d + channel] * fx
                output[out + channel] = round(top * (1 - fy) + bottom * fy)
    return output


def write_png(path, size, pixels):
    def chunk(kind, payload):
        return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff)
    rows = b''.join(b'\0' + pixels[y * size * 3:(y + 1) * size * 3] for y in range(size))
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b'')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
