"""Generate the Alexa skill icons (108x108 and 512x512 PNG), standard library only.

A white alarm clock with a red "!" on a deep-orange circle.
Run: python tools/gen_icons.py  ->  alexa/icons/icon_108.png, icon_512.png
"""
import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "alexa" / "icons"
ORANGE = (230, 81, 0)
WHITE = (255, 255, 255)
RED = (198, 40, 40)


def pixel(x, y):
    """Colour at (x, y) in a 1.0 x 1.0 square; None = transparent."""
    dx, dy = x - 0.5, y - 0.5
    r = math.hypot(dx, dy)
    if r > 0.48:
        return None
    # Bells: two small circles top-left / top-right of the clock.
    for bx in (0.30, 0.70):
        if math.hypot(x - bx, y - 0.25) < 0.08:
            return WHITE
    cx, cy = 0.5, 0.55
    cr = math.hypot(x - cx, y - cy)
    if cr < 0.27:
        if cr > 0.22:
            return WHITE  # clock rim
        # "!" in the clock face.
        if abs(x - cx) < 0.035 and cy - 0.15 < y < cy + 0.05:
            return RED
        if math.hypot(x - cx, y - (cy + 0.11)) < 0.035:
            return RED
        return WHITE
    return ORANGE


def png(size, path=None):
    """Renders the icon at size x size; writes it to path if given, returns the PNG bytes."""
    rows = []
    for py in range(size):
        row = bytearray([0])  # filter: none
        for px in range(size):
            # 3x3 supersampling for smooth edges.
            acc = [0, 0, 0, 0]
            for sy in range(3):
                for sx in range(3):
                    c = pixel((px + (sx + 0.5) / 3) / size, (py + (sy + 0.5) / 3) / size)
                    if c:
                        acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; acc[3] += 255
            n = acc[3] // 255
            row += bytes([acc[0] // n, acc[1] // n, acc[2] // n, acc[3] // 9] if n else [0, 0, 0, 0])
        rows.append(bytes(row))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
    data += chunk(b"IEND", b"")
    if path:
        path.write_bytes(data)
        print(f"wrote {path}")
    return data


def ico(sizes, path):
    """Windows .ico holding one PNG per size (supported since Vista)."""
    images = [png(s) for s in sizes]
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries = b""
    for size, data in zip(sizes, images):
        dim = 0 if size >= 256 else size  # 0 means 256 in the ICO format.
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    path.write_bytes(header + entries + b"".join(images))
    print(f"wrote {path}")


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    OUT.mkdir(parents=True, exist_ok=True)
    png(108, OUT / "icon_108.png")
    png(512, OUT / "icon_512.png")
    # Windows program icon (taskbar, Start menu, installer shortcuts) and tray icon.
    ico([16, 24, 32, 48, 64, 256], root / "windows" / "runner" / "resources" / "app_icon.ico")
    png(64, root / "assets" / "icons" / "tray.png")
