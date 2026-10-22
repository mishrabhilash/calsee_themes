"""Builds the README / pub.dev images from screenshots_test.dart's output.

Run from example/ after the test:  python3 screenshots/compose.py
Writes ../doc/families.png (all families), ../doc/swipe.gif (a theme
swipe) and ../doc/family_<name>.png (one per family, for pubspec
`screenshots:`).
"""

import pathlib

from PIL import Image

HERE = pathlib.Path(__file__).parent
OUT = HERE / "out"
DOC = HERE.parent.parent / "doc"
ORDER = [
    "claymorphism", "liquidGlass", "neoPop", "retro", "cyberpunk", "paperInk",
    "neumorphism", "y2kChrome", "vaporwave", "neoBrutalism", "m3Expressive",
    "bauhaus",
]


def main():
    DOC.mkdir(exist_ok=True)
    tiles = []
    for name in ORDER:
        img = Image.open(OUT / f"family_{name}.png").convert("RGB")
        img.resize((390, 844), Image.LANCZOS).save(
            DOC / f"family_{name}.png", optimize=True)
        tiles.append(img.resize((260, 563), Image.LANCZOS))

    cols, gap = 6, 16
    w, h = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    grid = Image.new("RGB", (cols * w + (cols + 1) * gap,
                             rows * h + (rows + 1) * gap), (245, 245, 245))
    for i, tile in enumerate(tiles):
        r, c = divmod(i, cols)
        grid.paste(tile, (gap + c * (w + gap), gap + r * (h + gap)))
    grid.save(DOC / "families.png", optimize=True)

    frames = [Image.open(p).convert("RGB").resize((300, 649), Image.LANCZOS)
              for p in sorted((OUT / "swipe").glob("frame_*.png"))]
    frames[0].save(DOC / "swipe.gif", save_all=True, append_images=frames[1:],
                   duration=80, loop=0, optimize=True)


if __name__ == "__main__":
    main()
