"""Re-slice EcoMayor sprite sheets into game assets.

Finds each item on a sheet by connected components (ignoring the text labels),
crops it tightly, strips the dark frame from boxed tiles, and gives free-standing
icons a transparent background.

Run from the repo root:
    uv run --with pillow --with numpy --with scipy python tools/slice_sheets.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "raw_sheets"
OUT = ROOT / "eco_mayor" / "assets" / "images"


def find_items(img: Image.Image, bg: str, min_h: int, dilate: int):
    """Return bounding boxes (x0, y0, x1, y1) of items, row-major order."""
    a = np.asarray(img.convert("RGB")).astype(int)
    if bg == "white":
        mask = a.min(axis=2) < 225
    else:
        mask = a.max(axis=2) > 40
    if dilate:
        mask = ndimage.binary_dilation(mask, iterations=dilate)
    labels, _ = ndimage.label(mask)
    boxes = []
    for sl in ndimage.find_objects(labels):
        y, x = sl
        h, w = y.stop - y.start, x.stop - x.start
        if h >= min_h and w >= min_h:
            boxes.append((x.start + dilate, y.start + dilate, x.stop - dilate, y.stop - dilate))
    # group into rows by vertical centre, then sort each row left-to-right
    boxes.sort(key=lambda b: (b[1] + b[3]) / 2)
    rows, cur = [], []
    for b in boxes:
        if cur and (b[1] + b[3]) / 2 - (cur[0][1] + cur[0][3]) / 2 > 60:
            rows.append(cur)
            cur = []
        cur.append(b)
    if cur:
        rows.append(cur)
    return [b for r in rows for b in sorted(r, key=lambda b: b[0])]


def strip_frame(tile: Image.Image, pad: int = 2) -> Image.Image:
    """Cut inward until the dark outline frame is gone on every side."""
    a = np.asarray(tile.convert("RGB")).astype(int)
    dark = a.max(axis=2) < 70

    def edge(lines):
        for i, line in enumerate(lines):
            if dark[line].mean() < 0.5:
                return i
        return 0

    h, w = dark.shape
    top = edge([np.s_[i, :] for i in range(h // 4)])
    bottom = edge([np.s_[h - 1 - i, :] for i in range(h // 4)])
    left = edge([np.s_[:, i] for i in range(w // 4)])
    right = edge([np.s_[:, w - 1 - i] for i in range(w // 4)])
    return tile.crop((left + pad, top + pad, w - right - pad, h - bottom - pad))


def knock_out(tile: Image.Image, bg_rgb, thresh: int) -> Image.Image:
    """Flood-fill the background from the border to transparent."""
    rgba = tile.convert("RGBA")
    w, h = rgba.size
    marker = (255, 0, 255, 0)
    seeds = [(x, 0) for x in range(0, w, 4)] + [(x, h - 1) for x in range(0, w, 4)]
    seeds += [(0, y) for y in range(0, h, 4)] + [(w - 1, y) for y in range(0, h, 4)]
    for s in seeds:
        px = rgba.getpixel(s)
        if px[3] and max(abs(px[i] - bg_rgb[i]) for i in range(3)) <= thresh:
            ImageDraw.floodfill(rgba, s, marker, thresh=thresh)
    a = np.asarray(rgba).copy()
    hole = (a[..., 0] == 255) & (a[..., 1] == 0) & (a[..., 2] == 255) & (a[..., 3] == 0)
    a[hole] = 0
    # soften the fringe: pixels next to the hole that are close to bg get partial alpha
    near = ndimage.binary_dilation(hole, iterations=1) & ~hole
    dist = np.abs(a[..., :3].astype(int) - np.array(bg_rgb)).max(axis=2)
    a[near, 3] = np.clip(dist[near] * 4, 0, 255)
    return Image.fromarray(a, "RGBA")


def square(img: Image.Image, size: int) -> Image.Image:
    """Fit into a transparent square canvas without distortion."""
    img = img.copy()
    img.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - img.width) // 2, (size - img.height) // 2), img.convert("RGBA"))
    return canvas


def save(img: Image.Image, rel: str, size):
    path = OUT / rel
    if isinstance(size, tuple):
        img = img.resize(size, Image.LANCZOS)
    else:
        img = square(img, size)
    img.save(path)
    print(f"  {rel:40s} {img.size[0]}x{img.size[1]}")


def tiles_sheet(sheet, names, min_h, sizes):
    img = Image.open(RAW / sheet)
    boxes = find_items(img, "white", min_h, dilate=0)
    print(f"{sheet}: {len(boxes)} items")
    assert len(boxes) == len(names), (sheet, len(boxes), boxes)
    return img, boxes


def main():
    # --- terrain + roads (framed squares, fully opaque tiles) ---
    terrain = ["tiles/grass", "tiles/grass_dead", "tiles/dirt", "tiles/water_clean",
               "tiles/water_polluted", "tiles/sand", "tiles/concrete",
               "buildings/road_h", "buildings/road_v", "buildings/road_cross"]
    img, boxes = tiles_sheet("terrain.jpg", terrain, 150, None)
    for name, b in zip(terrain, boxes):
        save(strip_frame(img.crop(b), pad=7).convert("RGBA"), name + ".png", (128, 128))

    # --- buildings (framed squares; the wind turbine is free-standing) ---
    buildings = [("coal_plant", 2), ("factory", 2), ("oil_refinery", 2), ("landfill", 2),
                 ("house", 1), ("apartment", 2),
                 ("park", 1), ("solar_farm", 2), ("wind_turbine", 1), ("water_treatment", 2),
                 ("recycling_center", 2), ("composting", 1),
                 ("green_roof", 1), ("sewage_treatment", 2), ("hospital", 2), ("school", 2),
                 ("ev_station", 1)]
    img = Image.open(RAW / "buildings.jpg")
    boxes = find_items(img, "white", 150, dilate=0)
    print(f"buildings.jpg: {len(boxes)} items")
    assert len(boxes) == len(buildings), boxes
    for (name, cells), b in zip(buildings, boxes):
        crop = img.crop(b)
        px = 128 * cells
        if name == "wind_turbine":
            save(knock_out(crop, (255, 255, 255), 28), f"buildings/{name}.png", px)
        else:
            save(strip_frame(crop).convert("RGBA"), f"buildings/{name}.png", (px, px))

    # --- UI icons (free-standing on white) ---
    icons = ["ui/icon_funds", "ui/icon_gems", "ui/icon_population", "ui/icon_happiness",
             "ui/icon_aqi", "ui/icon_water", "ui/icon_soil", "ui/icon_noise",
             "ui/streak_flame", "ui/btn_demolish", "ui/icon_trophy"]
    img = Image.open(RAW / "ui.jpg")
    boxes = find_items(img, "white", 100, dilate=6)
    print(f"ui.jpg: {len(boxes)} items")
    assert len(boxes) == len(icons), boxes
    for name, b in zip(icons, boxes):
        x0, y0, x1, y1 = b
        crop = img.crop((x0 - 6, y0 - 6, x1 + 6, y1 + 6))
        save(knock_out(crop, (255, 255, 255), 30), name + ".png", 96)

    # --- advisor portraits (framed) ---
    advisors = ["advisors/advisor_priya", "advisors/advisor_arjun",
                "advisors/advisor_meera", "advisors/advisor_rohan"]
    img, boxes = tiles_sheet("advisors.jpg", advisors, 200, None)
    for name, b in zip(advisors, boxes):
        save(img.crop(b).convert("RGBA"), name + ".png", (256, 256))

    # --- effects (on black) ---
    img = Image.open(RAW / "effects.jpg")
    boxes = find_items(img, "black", 60, dilate=12)
    print(f"effects.jpg: {len(boxes)} items -> {boxes}")


if __name__ == "__main__":
    main()
