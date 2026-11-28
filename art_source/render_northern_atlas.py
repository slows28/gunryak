"""Bake the offline relief from shadedrelief.jpg and Natural Earth GeoJSON.

Usage: python art_source/render_northern_atlas.py shadedrelief.jpg rivers.geojson
Projection bounds and canvas size come from the game map so that its sites stay registered.
"""
import argparse
import json
import math
from pathlib import Path
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SCALE = 2


def coordinates(script, name, constructor):
    match = re.search(rf"const {name} := {constructor}\(([^)]+)\)", script)
    return tuple(float(part) for part in match[1].split(","))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ("relief", "rivers"):
        parser.add_argument(arg, type=Path)
    args = parser.parse_args()
    script = (ROOT / "scripts/northern_atlas.gd").read_text()
    west, south, east, north = coordinates(script, "BOUNDS", "Vector4")
    width, height = map(int, coordinates(script, "MAP_SIZE", "Vector2"))
    size = width * SCALE, height * SCALE

    def point(lon, lat):
        return (lon - west) * size[0] / (east - west), (north - lat) * size[1] / (north - south)

    src = Image.open(args.relief).convert("RGB")
    box = ((west + 180) / 360 * src.width, (90 - north) / 180 * src.height,
           (east + 180) / 360 * src.width, (90 - south) / 180 * src.height)
    relief = src.transform(size, Image.Transform.EXTENT, box, Image.Resampling.BICUBIC)
    relief = relief.filter(ImageFilter.UnsharpMask(radius=3.0, percent=100, threshold=3))
    rgb = np.asarray(relief, dtype=float)
    shade = np.clip((rgb @ [0.30, 0.59, 0.11] - 101) / 139, 0, 1)[..., None]
    umber = np.array([136, 133, 109])
    paper = np.array([230, 216, 181])
    base = umber + (paper - umber) * shade
    # Preserve the separate lowland tint of the source map.
    lowland = np.clip((rgb[:, :, 1] - rgb[:, :, 0] + 2) / 24, 0, 1)[..., None]
    base += lowland * np.array([-22, -4, 2])
    # Fine engraved hatching follows shaded slopes and recedes on the valley floors.
    y, x = np.indices(size[::-1])
    hatch = np.maximum(0, np.cos((x * 0.44 + y * 0.81) * np.pi / 3)) ** 6
    base -= (hatch * 11)[..., None] * (1 - shade) ** 1.4
    grain = np.random.default_rng(228).normal(0, 1.35, size[::-1])[..., None]
    image = Image.fromarray(np.clip(base + grain, 0, 255).astype("uint8"))
    ink = ImageDraw.Draw(image)

    for feature in json.loads(args.rivers.read_text())["features"]:
        geom = feature["geometry"]
        lines = geom["coordinates"] if geom["type"] == "MultiLineString" else [geom["coordinates"]]
        for line in lines:
            if not any(west <= lon <= east and south <= lat <= north for lon, lat in line):
                continue
            path = [point(lon, lat) for lon, lat in line]
            main_river = feature["properties"]["name"] in ("Wei", "Han")
            ink.line(path, fill="#e3d9bc", width=6 if main_river else 4)
            ink.line(path, fill="#548086" if main_river else "#839795", width=3 if main_river else 2)

    # A ground scale calculated at the center latitude of this plate.
    mean_lat = math.radians((south + north) / 2)
    scale_length = 100 * width / ((east - west) * 111.32 * math.cos(mean_lat))
    x, y = 16 * SCALE, 63 * SCALE
    end = round(x + scale_length * SCALE)
    ink.line([(x,y), (end,y)], fill="#4d5546", width=2)
    for tick in (x, end):
        ink.line([(tick,y-5), (tick,y+2)], fill="#4d5546", width=2)
    ink.rectangle((0, 0, size[0]-1, size[1]-1), outline="#9a926f", width=2)
    image.save(ROOT / "assets/art/northern_theater.webp", quality=92, method=6)


if __name__ == "__main__":
    main()
