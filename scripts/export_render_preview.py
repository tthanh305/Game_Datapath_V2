"""Convert the renderer testbench's binary PPM output to PNG (stdlib only)."""
from pathlib import Path
import struct
import zlib


def png_chunk(kind, payload):
    return (struct.pack('>I', len(payload)) + kind + payload
            + struct.pack('>I', zlib.crc32(kind + payload) & 0xFFFFFFFF))


def convert(path):
    data = path.read_bytes()
    header = b'P6\n1280 720\n255\n'
    if not data.startswith(header):
        raise ValueError(f'Unexpected renderer PPM header: {path}')
    pixels = data[len(header):]
    width, height = 1280, 720
    stride = width * 3
    if len(pixels) != stride * height:
        raise ValueError(f'Unexpected renderer pixel count: {path}: {len(pixels)} bytes')
    raw = b''.join(b'\0' + pixels[row*stride:(row+1)*stride] for row in range(height))
    png = (b'\x89PNG\r\n\x1a\n'
           + png_chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
           + png_chunk(b'IDAT', zlib.compress(raw))
           + png_chunk(b'IEND', b''))
    result = path.with_suffix('.png')
    result.write_bytes(png)
    print(result)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1] / 'verification' / 'color_mapper'
    for name in ('game_initial.ppm', 'game_win.ppm'):
        convert(root / name)
