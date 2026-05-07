#!/usr/bin/env python3
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT.parent / "assets/album-character-concepts"
OUTPUT_DIR = ROOT / "Sources" / "JayPetApp" / "Resources" / "processed_album_art"
MAX_WIDTH = 180
MAX_HEIGHT = 215
PADDING = 10
MIN_ENCLOSED_WHITE_AREA = 80


def is_near_white(pixel):
    r, g, b, a = pixel
    return a > 0 and r >= 238 and g >= 238 and b >= 238


def edge_connected_white_mask(image):
    width, height = image.size
    pixels = image.load()
    seen = [[False] * width for _ in range(height)]
    q = deque()

    for x in range(width):
        for y in (0, height - 1):
            if not seen[y][x] and is_near_white(pixels[x, y]):
                seen[y][x] = True
                q.append((x, y))

    for y in range(height):
        for x in (0, width - 1):
            if not seen[y][x] and is_near_white(pixels[x, y]):
                seen[y][x] = True
                q.append((x, y))

    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            if seen[ny][nx] or not is_near_white(pixels[nx, ny]):
                continue
            seen[ny][nx] = True
            q.append((nx, ny))

    return seen


def enclosed_white_mask(image):
    width, height = image.size
    pixels = image.load()
    seen = [[False] * width for _ in range(height)]
    keep = [[False] * width for _ in range(height)]

    for start_y in range(height):
        for start_x in range(width):
            if seen[start_y][start_x] or not is_near_white(pixels[start_x, start_y]):
                continue

            q = deque([(start_x, start_y)])
            seen[start_y][start_x] = True
            component = []
            touches_edge = False

            while q:
                x, y = q.popleft()
                component.append((x, y))
                if x == 0 or y == 0 or x == width - 1 or y == height - 1:
                    touches_edge = True

                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    if seen[ny][nx] or not is_near_white(pixels[nx, ny]):
                        continue
                    seen[ny][nx] = True
                    q.append((nx, ny))

            if touches_edge or len(component) < MIN_ENCLOSED_WHITE_AREA:
                continue

            for x, y in component:
                keep[y][x] = True

    return keep


def trim_and_fit(image):
    bbox = image.getbbox()
    if bbox is None:
        return image

    left = max(bbox[0] - PADDING, 0)
    top = max(bbox[1] - PADDING, 0)
    right = min(bbox[2] + PADDING, image.width)
    bottom = min(bbox[3] + PADDING, image.height)
    cropped = image.crop((left, top, right, bottom))
    cropped.thumbnail((MAX_WIDTH, MAX_HEIGHT), Image.Resampling.LANCZOS)
    return cropped


def process_file(path):
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    mask = edge_connected_white_mask(image)
    enclosed_mask = enclosed_white_mask(image)

    for y, row in enumerate(mask):
        for x, should_clear in enumerate(row):
            if should_clear or enclosed_mask[y][x]:
                pixels[x, y] = (255, 255, 255, 0)

    image = trim_and_fit(image)
    out = OUTPUT_DIR / path.name
    image.save(out, optimize=True)
    return out


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUTPUT_DIR.glob("*.png"):
        old.unlink()

    files = sorted(path for path in SOURCE_DIR.glob("*.png") if path.is_file())
    for path in files:
        out = process_file(path)
        print(f"{path.name} -> {out.name}")


if __name__ == "__main__":
    main()
