# Nano Banana prompts for the city map

For every prompt, **attach `raw_sheets/terrain.jpg` as a style reference** so the
new tiles match the existing grass, water and road tiles.

Save the results in this folder (`raw_sheets/new/`) with exactly these names:
`forest.png`, `river.png` and `roads.png`. JPG is fine too.

---

## 1. forest.png: forest tiles

> Pixel art sprite sheet in the exact style of the attached reference image: 16-bit SNES-era, top-down (straight overhead) view, same colour palette and outline style. Plain pure white background. A 4 by 2 grid of 8 square tiles, all the same size, evenly spaced, each tile with a thin dark outline frame, and a short text label in a pixel font centred under each tile.
> Row 1 (healthy, lush green): "FOREST A": dense tree canopy filling the whole tile, round tree crowns seen from above, several shades of green. "FOREST B": the same but with a different tree arrangement. "FOREST C": dense canopy with one small clearing showing grass. "FOREST EDGE": trees on the top half, grass on the bottom half.
> Row 2 (damaged by pollution): "DEAD FOREST A", "DEAD FOREST B", "DEAD FOREST C", "DEAD FOREST EDGE": the same four layouts, but the trees are leafless, grey-brown and dying on dry brown ground.
> Each forest tile must tile seamlessly next to itself on all four sides. No shadows outside the tiles, no other objects, no title.

## 2. river.png: narrow river tiles

> Pixel art sprite sheet in the exact style of the attached reference image: 16-bit SNES-era, top-down (straight overhead) view, same colour palette and outline style. Plain pure white background. A 4 by 2 grid of 8 square tiles, all the same size, evenly spaced, each tile with a thin dark outline frame, and a short text label in a pixel font centred under each tile.
> Every tile is lush green grass (matching the reference grass) with a narrow bright cyan river running through it. The river is exactly one third of the tile wide, with thin sandy banks, and always enters and leaves at the exact centre of a tile edge so tiles connect seamlessly.
> Tiles: "RIVER VERTICAL" (top edge to bottom edge), "RIVER HORIZONTAL" (left edge to right edge), "BEND TOP-RIGHT" (connects top edge to right edge with a smooth curve), "BEND RIGHT-BOTTOM", "BEND BOTTOM-LEFT", "BEND LEFT-TOP", "RIVER SOURCE" (a small spring pond in the centre flowing out of the bottom edge), "RIVER BRIDGE" (vertical river with a small stone bridge crossing it left to right).
> No other objects, no title.

## 3. roads.png: road network tiles

> Pixel art sprite sheet in the exact style of the attached reference image: 16-bit SNES-era, top-down (straight overhead) view, same colour palette and outline style. Plain pure white background. A 4 by 2 grid of 8 square tiles, all the same size, evenly spaced, each tile with a thin dark outline frame, and a short text label in a pixel font centred under each tile.
> Every tile is green grass (matching the reference grass) with a dark grey asphalt road, light grey kerbs and dashed yellow centre lines, exactly like the reference "HORIZ. ROAD". The road is exactly half of the tile wide and always meets the exact centre of a tile edge so tiles connect seamlessly.
> Tiles: "ROAD VERTICAL", "ROAD HORIZONTAL", "CORNER TOP-RIGHT" (road connects top edge and right edge), "T-JUNCTION" (road connects left, right and bottom edges), "CROSSROAD" (all four edges), "DEAD END" (road comes in from the bottom edge and ends in a rounded cul-de-sac in the centre), "ZEBRA CROSSING" (horizontal road with white zebra stripes), "ROUNDABOUT" (all four edges meet a small round green island in the centre).
> No other objects, no title.

---

## 4. menu_icons.png: menu and button icons

Attach `raw_sheets/ui.jpg` (not terrain.jpg) as the style reference for this one.

> Pixel art icon sheet in the exact style of the attached reference image: 16-bit SNES-era pixel art icons with dark outlines and bright shading, same palette and line weight. Plain pure white background. A 4 by 3 grid of 12 separate icons, evenly spaced with generous white space between them, no frames, and a short text label in a pixel font centred under each icon.
> Row 1: "GUIDE BOOK" (an open green book with a leaf bookmark), "EARTH" (a green and blue planet Earth with a small leaf sprouting on top), "EXIT DOOR" (a wooden door slightly open with an arrow pointing out), "BACK ARROW" (a chunky green arrow pointing left).
> Row 2: "SAPLING" (a small healthy sapling in fresh soil), "SMOGGY TOWN" (two small buildings under a grey smog cloud), "BURNING FACTORY" (a factory with a smokestack and orange flames), "STAR" (a shiny gold star).
> Row 3: "SOUND ON" (a speaker with sound waves), "SOUND OFF" (a speaker with a red cross), "SAVE DISK" (a green floppy disk), "SETTINGS GEAR" (a silver cog wheel).
> Every icon is centred and fully visible, nothing touches another icon, no title.
