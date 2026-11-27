"""Rebuild the field standards with Pillow and Noto Serif CJK Bold (Korean face)."""
from __future__ import annotations

import argparse
import math
from pathlib import Path
import random
import re

from PIL import Image, ImageColor, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CELL = (64, 80)


def cloth(dye: str, enemy: bool) -> tuple[Image.Image, Image.Image]:
    image = Image.new("RGBA", CELL)
    base = ImageColor.getrgb(dye)
    rng = random.Random(131)
    width, height = CELL
    for y in range(height):
        for x in range(width):
            light = (1 + 0.09 * math.cos((x - 6) * 0.23)
                     + 0.035 * math.sin(x * 0.51 + y * 0.07)
                     + 0.06 * (1 - y / height) + 0.018 * (x % 2 + y % 2 - 1)
                     + rng.uniform(-0.023, 0.023))
            image.putpixel((x, y), tuple(min(255, round(channel * light)) for channel in base) + (255,))

    hem = ([(1, 1), (62, 3), (61, 75), (33, 61), (3, 78)] if enemy
           else [(1, 1), (62, 3), (60, 72), (48, 73), (35, 71), (20, 75), (2, 77)])
    mask = Image.new("L", CELL)
    ImageDraw.Draw(mask).polygon(hem, fill=255)
    draw = ImageDraw.Draw(image)
    draw.line(hem + [hem[0]], fill="#352c23", width=1)
    draw.line([(3, 72), (3, 2), (60, 2), (60, 72 if enemy else 74)], fill="#897f67", width=2)
    border = [(3, 74), (33, 63), (60, 74)] if enemy else [(3, 74), (60, 74)]
    draw.line(border, fill="#948a70", width=2)
    draw.rectangle((5, 4, 59, 13), fill="#963e32" if enemy else "#304c77")
    draw.line((5, 14, 59, 14), fill="#ab9873", width=1)
    for x in range(10, 56, 10):
        draw.line((x, 7, x + 3, 10), fill="#b7a184", width=2)
        if enemy:
            draw.line((x + 3, 10, x + 6, 7), fill="#b7a184", width=2)
    for x, sign in [(7, 1), (56, -1)]:
        draw.line([(x, 24), (x, 18), (x + 5 * sign, 18)], fill="#847965", width=1)
    return image, mask


def render(font_path: Path, output: Path) -> None:
    definition = (ROOT / "scripts/corps_standard.gd").read_text(encoding="utf-8")
    colors = re.findall(r'Color\("(#\w+)"\)', definition.split("const NAMES")[0])
    glyphs = re.search(r'GLYPHS := "(.*?)"', definition).group(1) + " "
    width, height = CELL
    font = ImageFont.truetype(str(font_path), 44, index=1)
    atlas = Image.new("RGBA", (width * len(glyphs), height * len(colors)))
    for side, dye in enumerate(colors):
        base, mask = cloth(dye, bool(side))
        for column, glyph in enumerate(glyphs):
            tile = base.copy()
            if glyph.strip():
                left, top, right, bottom = font.getbbox(glyph)
                anchor = ((width - left - right) / 2, (84 - top - bottom) / 2)
                ImageDraw.Draw(tile).text(anchor, glyph, font=font, fill="#e6d8b2",
                                          stroke_width=1, stroke_fill="#3a2c28")
            tile.putalpha(mask)
            atlas.paste(tile, (column * width, side * height))
    atlas.save(output, lossless=True, method=6)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--font", type=Path, default=Path("/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"))
    parser.add_argument("--output", type=Path, default=ROOT / "assets/art/corps_standards.webp")
    args = parser.parse_args()
    render(args.font, args.output)
