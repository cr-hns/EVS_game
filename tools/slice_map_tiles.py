"""Slice the map tile sheets in raw_sheets/new/ (forest, river, roads).

Tiles are named by which sides connect, in the order t r b l:
  road_rl = horizontal, road_tr = top+right corner, road_trbl = crossroad,
  road_b  = dead end entering from the bottom.
Missing road rotations are made by rotating the drawn pieces. The grass inside
road and river tiles is made transparent so the map's own grass (healthy or
dead) shows through. Polluted river tiles are recoloured from the clean ones.

Run from the repo root:
    uv run --with pillow --with numpy --with scipy python tools/slice_map_tiles.py
"""

import numpy as np
from PIL import Image

from slice_sheets import OUT, RAW, find_items, knock_out, square, strip_frame

NEW = RAW / "new"
SIZE = 128
ROT_CW = {"t": "r", "r": "b", "b": "l", "l": "t"}  # where each side goes on a 90° CW turn


def mask_name(sides: set) -> str:
    return "".join(s for s in "trbl" if s in sides)


def rotate_cw(img: Image.Image, sides: set, turns: int):
    for _ in range(turns):
        img = img.transpose(Image.ROTATE_270)  # PIL ROTATE_270 = 90° clockwise
        sides = {ROT_CW[s] for s in sides}
    return img, sides


def tiles(sheet: str, count: int):
    img = Image.open(NEW / sheet).convert("RGB")
    boxes = find_items(img, "white", 150, dilate=0)
    print(f"{sheet}: {len(boxes)} tiles")
    assert len(boxes) == count, boxes
    out = []
    for b in boxes:
        t = strip_frame(img.crop(b), pad=11).resize((SIZE, SIZE), Image.LANCZOS)
        out.append(t.convert("RGBA"))
    return out


def knock_out_grass(tile: Image.Image) -> Image.Image:
    """Make green grass pixels transparent (roads/river keep their own colours)."""
    a = np.asarray(tile).astype(int).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    grass = (g > r + 18) & (g > b + 18)
    a[grass, 3] = 0
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def pollute(tile: Image.Image) -> Image.Image:
    """Recolour cyan water to murky green-brown, keeping its light/dark detail."""
    a = np.asarray(tile).astype(float).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    water = (b > r + 40) & (g > r + 25) & (a[..., 3] > 0)
    lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
    murky = np.stack([70 + 70 * lum, 85 + 60 * lum, 35 + 25 * lum], axis=-1)
    a[..., :3][water] = murky[water]
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def save(img: Image.Image, name: str):
    img.save(OUT / "tiles" / f"{name}.png")
    print(f"  tiles/{name}.png")


def main():
    # Forest: 4 healthy + 4 dead, kept as full opaque tiles.
    names = ["forest_a", "forest_b", "forest_c", "forest_edge",
             "forest_dead_a", "forest_dead_b", "forest_dead_c", "forest_dead_edge"]
    for name, t in zip(names, tiles("forest.jpg", 8)):
        save(t, name)

    # River: what each drawn tile actually connects (the sheet labels are off).
    river = tiles("river.jpg", 8)
    river_sides = [{"t", "b"}, {"l", "r"}, {"t", "r"}, {"l", "b"},
                   {"b", "r"}, {"l", "t"}, None, "bridge"]
    for t, sides in zip(river, river_sides):
        if sides is None:
            continue  # spring/source tile is not used on this map
        clean = knock_out_grass(t)
        name = "river_bridge" if sides == "bridge" else f"river_{mask_name(sides)}"
        save(clean, name)
        save(pollute(clean), name + "_polluted")

    # Roads: straight, corner, T, cross, dead end; rotate to fill every mask.
    road = tiles("roads.jpg", 8)
    pieces = [
        (road[0], {"t", "b"}, 0),
        (road[1], {"l", "r"}, 0),
        (road[2], {"l", "b"}, 4),  # corner, all 4 rotations
        (road[3], {"l", "r", "b"}, 4),  # T-junction, all 4 rotations
        (road[4], {"t", "r", "b", "l"}, 0),
        (road[5], {"b"}, 4),  # dead end, all 4 rotations
    ]
    done = set()
    for img, sides, turns in pieces:
        for k in range(max(turns, 1)):
            rimg, rs = rotate_cw(img, sides, k)
            name = f"road_{mask_name(rs)}"
            if name in done:
                continue
            done.add(name)
            save(knock_out_grass(rimg), name)
    print(f"{len(done)} road masks")

    # Menu icons: free-standing on white, so cut out with transparency.
    icons = ["book", "earth", "exit", "back", "sapling", "smoggy_town", "burning_factory",
             "star", "sound_on", "sound_off", "save", "settings"]
    img = Image.open(NEW / "menu_icons.jpg").convert("RGB")
    boxes = find_items(img, "white", 100, dilate=10)
    print(f"menu_icons.jpg: {len(boxes)} icons")
    assert len(boxes) == len(icons), boxes
    for name, (x0, y0, x1, y1) in zip(icons, boxes):
        # Drop a text label: a short band of ink below a blank gap.
        ink = (np.asarray(img.crop((x0, y0, x1, y1))).min(axis=2) < 200).any(axis=1)
        rows = np.where(ink)[0]
        gaps = [i for i in range(1, len(rows)) if rows[i] - rows[i - 1] > 4]
        if gaps and rows[-1] - rows[gaps[-1]] < 45:
            y1 = y0 + rows[gaps[-1] - 1] + 2
            cols = np.where((np.asarray(img.crop((x0, y0, x1, y1))).min(axis=2) < 200).any(axis=0))[0]
            x0, x1 = x0 + cols[0], x0 + cols[-1] + 1
        crop = img.crop((x0 - 6, y0 - 6, x1 + 6, y1 + 6))
        square(knock_out(crop, (255, 255, 255), 30), 96).save(OUT / "ui" / f"menu_{name}.png")
        print(f"  ui/menu_{name}.png")


if __name__ == "__main__":
    main()
