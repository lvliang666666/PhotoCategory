from collections import deque
from pathlib import Path
import sys

from PIL import Image, ImageFilter


def main() -> None:
    source = Path(sys.argv[1])
    root = Path(__file__).resolve().parents[1]
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    seen = bytearray(width * height)
    queue = deque()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))

    # Remove only the near-black area connected to the canvas edge. Dark
    # details in the camera lens remain untouched because they are enclosed.
    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if seen[index]:
            continue
        red, green, blue, _ = pixels[x, y]
        if max(red, green, blue) > 72 or max(red, green, blue) - min(
            red, green, blue
        ) > 20:
            continue
        seen[index] = 1
        pixels[x, y] = (red, green, blue, 0)
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))

    image.putalpha(image.getchannel("A").filter(ImageFilter.GaussianBlur(1.0)))
    master = root / "assets" / "branding" / "app_icon.png"
    master.parent.mkdir(parents=True, exist_ok=True)
    image.save(master, optimize=True)

    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, size in sizes.items():
        output = (
            root
            / "android"
            / "app"
            / "src"
            / "main"
            / "res"
            / f"mipmap-{density}"
            / "ic_launcher.png"
        )
        output.parent.mkdir(parents=True, exist_ok=True)
        image.resize((size, size), Image.Resampling.LANCZOS).save(output, optimize=True)

    print(f"master={image.size}, alpha_bbox={image.getchannel('A').getbbox()}")


if __name__ == "__main__":
    main()
