#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT.parent / "assets/animated-album-sheets" / "jay"
RESOURCE_ROOT = ROOT / "Sources" / "JayPetApp" / "Resources" / "album_animations"
QA_ROOT = ROOT / "build" / "animation_qa"
CANVAS_SIZE = (220, 260)
MAX_CONTENT_SIZE = (180, 215)
PADDING = 10
BACKGROUND_THRESHOLD = 238
ALPHA_THRESHOLD = 5
MIN_DETACHED_COMPONENT_AREA = 80
MIN_ENCLOSED_WHITE_AREA = 80

ACTION_SPECS = {
    "idle.png": {"id": "idle", "prefix": "idle", "fps": 6, "loop": True},
    "enter.png": {"id": "enter", "prefix": "enter", "fps": 12, "loop": False},
    "exit.png": {"id": "exit", "prefix": "exit", "fps": 12, "loop": False},
    "dragging.png": {"id": "dragging", "prefix": "drag", "fps": 10, "loop": True},
}

GRID_LAYOUT_OVERRIDES = {
    "capricorn": {
        "idle.png": {"columns": 8, "rows": 2},
        "enter.png": {"columns": 9, "rows": 2},
        "exit.png": {"columns": 9, "rows": 2},
        "dragging.png": {"columns": 8, "rows": 2},
    },
    "opus12": {
        "idle.png": {"columns": 8, "rows": 2, "label_position": "above"},
        "enter.png": {"columns": 9, "rows": 2, "label_position": "above"},
        "exit.png": {"columns": 6, "rows": 3, "label_position": "above"},
        "dragging.png": {"columns": 8, "rows": 2, "label_position": "above"},
    },
}

ACTION_SCALE_OVERRIDES = {
    "wow": {
        "idle.png": 0.84,
    },
    "opus12": {
        "enter.png": 1.07,
        "exit.png": 1.35,
        "dragging.png": 1.29,
    },
    "aiyo": {
        "dragging.png": 1.17,
    },
}

SHARED_SCALE_ALBUMS = {"opus12"}


@dataclass(frozen=True)
class Box:
    left: int
    top: int
    right: int
    bottom: int

    @property
    def width(self) -> int:
        return self.right - self.left

    @property
    def height(self) -> int:
        return self.bottom - self.top

    @property
    def center_x(self) -> float:
        return (self.left + self.right) / 2

    @property
    def center_y(self) -> float:
        return (self.top + self.bottom) / 2

    def expanded(self, pixels: int, image_size: tuple[int, int]) -> "Box":
        width, height = image_size
        return Box(
            max(self.left - pixels, 0),
            max(self.top - pixels, 0),
            min(self.right + pixels, width),
            min(self.bottom + pixels, height),
        )

    def as_tuple(self) -> tuple[int, int, int, int]:
        return (self.left, self.top, self.right, self.bottom)


def is_near_white(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 0 and r >= BACKGROUND_THRESHOLD and g >= BACKGROUND_THRESHOLD and b >= BACKGROUND_THRESHOLD


def edge_connected_background(image: Image.Image) -> list[list[bool]]:
    width, height = image.size
    pixels = image.load()
    seen = [[False] * width for _ in range(height)]
    q: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        if not seen[y][x] and is_near_white(pixels[x, y]):
            seen[y][x] = True
            q.append((x, y))

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)

    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < width and 0 <= ny < height:
                push(nx, ny)
    return seen


def clear_edge_background(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    mask = edge_connected_background(out)
    for y, row in enumerate(mask):
        for x, should_clear in enumerate(row):
            if should_clear:
                pixels[x, y] = (255, 255, 255, 0)
    return out


def clear_enclosed_white_regions(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    width, height = out.size
    pixels = out.load()
    seen = [[False] * width for _ in range(height)]

    for start_y in range(height):
        for start_x in range(width):
            if seen[start_y][start_x] or not is_near_white(pixels[start_x, start_y]):
                continue

            q: deque[tuple[int, int]] = deque([(start_x, start_y)])
            seen[start_y][start_x] = True
            component: list[tuple[int, int]] = []
            touches_edge = False

            while q:
                x, y = q.popleft()
                component.append((x, y))
                if x == 0 or y == 0 or x == width - 1 or y == height - 1:
                    touches_edge = True

                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < width and 0 <= ny < height:
                        if seen[ny][nx] or not is_near_white(pixels[nx, ny]):
                            continue
                        seen[ny][nx] = True
                        q.append((nx, ny))

            if touches_edge or len(component) < MIN_ENCLOSED_WHITE_AREA:
                continue

            for x, y in component:
                pixels[x, y] = (255, 255, 255, 0)

    return out


def alpha_bbox(image: Image.Image) -> Box | None:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return None
    return Box(*bbox)


def component_boxes(image: Image.Image) -> list[tuple[Box, int, tuple[float, float, float]]]:
    width, height = image.size
    pixels = image.load()
    seen = [[False] * width for _ in range(height)]
    comps: list[tuple[Box, int, tuple[float, float, float]]] = []

    for sy in range(height):
        for sx in range(width):
            if seen[sy][sx] or pixels[sx, sy][3] <= 0:
                continue
            q = deque([(sx, sy)])
            seen[sy][sx] = True
            min_x = max_x = sx
            min_y = max_y = sy
            count = 0
            total_r = total_g = total_b = 0

            while q:
                x, y = q.popleft()
                r, g, b, _ = pixels[x, y]
                count += 1
                total_r += r
                total_g += g
                total_b += b
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < width and 0 <= ny < height and not seen[ny][nx] and pixels[nx, ny][3] > 0:
                        seen[ny][nx] = True
                        q.append((nx, ny))

            comps.append((Box(min_x, min_y, max_x + 1, max_y + 1), count, (total_r / count, total_g / count, total_b / count)))
    return comps


def is_digit_component(box: Box, area: int, avg: tuple[float, float, float]) -> bool:
    r, g, b = avg
    dark = max(r, g, b) < 160 and (max(r, g, b) - min(r, g, b)) < 42
    return dark and 14 <= box.height <= 54 and 4 <= box.width <= 42 and 35 <= area <= 1400


def cluster_by_y(boxes: Iterable[Box], tolerance: float = 30) -> list[list[Box]]:
    rows: list[list[Box]] = []
    for box in sorted(boxes, key=lambda b: b.center_y):
        placed = False
        for row in rows:
            row_center = sum(item.center_y for item in row) / len(row)
            if abs(box.center_y - row_center) <= tolerance:
                row.append(box)
                placed = True
                break
        if not placed:
            rows.append([box])
    return rows


def merge_digit_boxes(row: list[Box]) -> list[Box]:
    labels: list[Box] = []
    current: Box | None = None
    for box in sorted(row, key=lambda b: b.left):
        if current is None:
            current = box
            continue
        same_label = box.left - current.right <= 34 and abs(box.center_y - current.center_y) <= 22
        if same_label:
            current = Box(
                min(current.left, box.left),
                min(current.top, box.top),
                max(current.right, box.right),
                max(current.bottom, box.bottom),
            )
        else:
            labels.append(current)
            current = box
    if current is not None:
        labels.append(current)
    return labels


def find_label_rows(image: Image.Image) -> list[list[Box]]:
    digit_components = [box for box, area, avg in component_boxes(image) if is_digit_component(box, area, avg)]
    rows = []
    for row in cluster_by_y(digit_components):
        labels = merge_digit_boxes(row)
        labels = [box for box in labels if 5 <= box.width <= 70 and 14 <= box.height <= 56]
        if len(labels) >= 4:
            rows.append(sorted(labels, key=lambda b: b.center_x))
    if rows:
        max_count = max(len(row) for row in rows)
        rows = [row for row in rows if len(row) >= max(4, int(max_count * 0.6))]
    rows.sort(key=lambda r: sum(box.center_y for box in r) / len(r))
    if not rows:
        raise RuntimeError("没有识别到帧编号，无法可靠切帧")
    return rows


def row_center_y(row: list[Box]) -> float:
    return sum(box.center_y for box in row) / len(row)


def select_label_rows_by_bands(label_rows: list[list[Box]], image_size: tuple[int, int], expected_rows: int) -> list[list[Box]]:
    _, height = image_size
    selected: list[list[Box]] = []
    for index in range(expected_rows):
        band_top = height * index / expected_rows
        band_bottom = height * (index + 1) / expected_rows
        candidates = [row for row in label_rows if band_top <= row_center_y(row) < band_bottom]
        if not candidates:
            raise RuntimeError(f"第 {index + 1} 行没有找到帧编号")
        selected.append(max(candidates, key=row_center_y))
    return selected


def x_edges_for_grid_row(row: list[Box], image_width: int, columns: int) -> list[int]:
    centers = [box.center_x for box in sorted(row, key=lambda b: b.center_x)]
    if len(centers) == columns - 1 and len(centers) >= 2:
        gaps = [b - a for a, b in zip(centers, centers[1:])]
        median_gap = sorted(gaps)[len(gaps) // 2]
        widest_gap_index = max(range(len(gaps)), key=lambda index: gaps[index])
        if gaps[widest_gap_index] > median_gap * 1.35:
            inferred_center = (centers[widest_gap_index] + centers[widest_gap_index + 1]) / 2
            centers.insert(widest_gap_index + 1, inferred_center)

    if len(centers) != columns:
        return [int(round(image_width * index / columns)) for index in range(columns + 1)]

    gaps = [b - a for a, b in zip(centers, centers[1:])]
    left_margin = max(int(round(centers[0] - (gaps[0] / 2))), 0)
    right_margin = min(int(round(centers[-1] + (gaps[-1] / 2))), image_width)
    x_edges = [left_margin]
    x_edges.extend(int(round((a + b) / 2)) for a, b in zip(centers, centers[1:]))
    x_edges.append(right_margin)
    return x_edges


def cell_boxes_for_fixed_grid(
    image_size: tuple[int, int],
    rows: list[list[Box]],
    columns: int,
    label_position: str | None = None,
) -> list[Box]:
    width, height = image_size
    cells: list[Box] = []
    previous_label_bottom = 0
    for row_index, row in enumerate(rows):
        x_edges = x_edges_for_grid_row(row, width, columns)
        label_top = min(box.top for box in row)
        label_bottom = max(box.bottom for box in row)
        if label_position == "above":
            row_top = min(label_bottom + 6, height)
            if row_index + 1 < len(rows):
                next_label_top = min(box.top for box in rows[row_index + 1])
                row_bottom = max(next_label_top - 6, row_top + 1)
            else:
                row_bottom = height
        else:
            row_top = 0 if previous_label_bottom == 0 else min(previous_label_bottom + 8, label_top)
            row_bottom = max(label_top - 6, row_top + 1)
        for frame_index in range(columns):
            cells.append(Box(x_edges[frame_index], row_top, x_edges[frame_index + 1], row_bottom))
        previous_label_bottom = label_bottom
    return cells


def erase_boxes(image: Image.Image, boxes: Iterable[Box]) -> Image.Image:
    out = image.copy()
    pixels = out.load()
    for box in boxes:
        area = box.expanded(7, out.size)
        for y in range(area.top, area.bottom):
            for x in range(area.left, area.right):
                pixels[x, y] = (255, 255, 255, 0)
    return out


def cell_boxes_for_labels(image_size: tuple[int, int], rows: list[list[Box]]) -> list[Box]:
    width, height = image_size

    cells: list[Box] = []
    first_label_top = min(box.top for box in rows[0])
    labels_are_above_frames = first_label_top < height * 0.12

    for row_index, row in enumerate(rows):
        label_top = min(box.top for box in row)
        label_bottom = max(box.bottom for box in row)

        if labels_are_above_frames:
            row_top = min(label_bottom + 6, height)
            if row_index + 1 < len(rows):
                next_label_top = min(box.top for box in rows[row_index + 1])
                row_bottom = max(next_label_top - 6, row_top + 1)
            else:
                row_bottom = height
        else:
            previous_label_bottom = 0 if row_index == 0 else max(box.bottom for box in rows[row_index - 1])
            row_top = 0 if previous_label_bottom == 0 else min(previous_label_bottom + 8, height)
            row_bottom = max(label_top - 6, row_top + 1)

        centers = [box.center_x for box in row]
        if len(centers) == 1:
            x_edges = [0, width]
        else:
            gaps = [b - a for a, b in zip(centers, centers[1:])]
            left_margin = max(int(round(centers[0] - (gaps[0] / 2))), 0)
            right_margin = min(int(round(centers[-1] + (gaps[-1] / 2))), width)
            x_edges = [left_margin]
            x_edges.extend(int(round((a + b) / 2)) for a, b in zip(centers, centers[1:]))
            x_edges.append(right_margin)
        for frame_index in range(len(row)):
            cells.append(Box(x_edges[frame_index], row_top, x_edges[frame_index + 1], row_bottom))
    return cells


def extract_raw_frames(sheet_path: Path, grid_layout: dict | None = None) -> list[Image.Image]:
    sheet = Image.open(sheet_path).convert("RGBA")
    cleaned = clear_enclosed_white_regions(clear_edge_background(sheet))
    label_rows = find_label_rows(cleaned)
    if grid_layout is not None:
        selected_rows = select_label_rows_by_bands(label_rows, cleaned.size, grid_layout["rows"])
        cells = cell_boxes_for_fixed_grid(
            cleaned.size,
            selected_rows,
            grid_layout["columns"],
            grid_layout.get("label_position"),
        )
        return [cleaned.crop(cell.as_tuple()) for cell in cells]

    all_labels = [box for row in label_rows for box in row]
    without_labels = erase_boxes(cleaned, all_labels)
    cells = cell_boxes_for_labels(cleaned.size, label_rows)
    frames = [without_labels.crop(cell.as_tuple()) for cell in cells]
    return frames


def measure_content_extent(raw_frames: list[Image.Image]) -> tuple[int, int]:
    max_width = 1
    max_height = 1
    for frame in raw_frames:
        bbox = alpha_bbox(frame)
        if bbox is not None:
            max_width = max(max_width, bbox.width + PADDING * 2)
            max_height = max(max_height, bbox.height + PADDING * 2)
    return max_width, max_height


def normalize_frames(
    raw_frames: list[Image.Image],
    scale_multiplier: float = 1.0,
    content_extent: tuple[int, int] | None = None,
) -> list[Image.Image]:
    content_boxes: list[Box | None] = []
    for frame in raw_frames:
        bbox = alpha_bbox(frame)
        content_boxes.append(bbox)

    max_width, max_height = content_extent or measure_content_extent(raw_frames)
    scale = min(MAX_CONTENT_SIZE[0] / max_width, MAX_CONTENT_SIZE[1] / max_height, 1.0) * scale_multiplier
    output: list[Image.Image] = []
    canvas_w, canvas_h = CANVAS_SIZE
    baseline = canvas_h - 12

    for frame, bbox in zip(raw_frames, content_boxes):
        canvas = Image.new("RGBA", CANVAS_SIZE, (255, 255, 255, 0))
        if bbox is None:
            output.append(canvas)
            continue

        crop_box = bbox.expanded(PADDING, frame.size)
        cropped = frame.crop(crop_box.as_tuple())
        target_size = (max(1, int(round(cropped.width * scale))), max(1, int(round(cropped.height * scale))))
        resized = cropped.resize(target_size, Image.Resampling.LANCZOS)
        x = int(round((canvas_w - resized.width) / 2))
        y = int(round(baseline - resized.height))
        y = max(min(y, canvas_h - resized.height), 0)
        canvas.alpha_composite(resized, (x, y))
        output.append(remove_detached_specks(canvas))
    return stabilize_vertical_anchor(output)


def translate_frame(image: Image.Image, delta_y: int) -> Image.Image:
    if delta_y == 0:
        return image
    shifted = Image.new("RGBA", image.size, (255, 255, 255, 0))
    shifted.alpha_composite(image, (0, delta_y))
    return shifted


def stabilize_vertical_anchor(frames: list[Image.Image]) -> list[Image.Image]:
    boxes = [alpha_bbox(frame) for frame in frames]
    visible_bottoms = [box.bottom for box in boxes if box is not None]
    if not visible_bottoms:
        return frames

    target_bottom = max(visible_bottoms)
    stabilized: list[Image.Image] = []
    for frame, box in zip(frames, boxes):
        if box is None:
            stabilized.append(frame)
            continue
        stabilized.append(translate_frame(frame, target_bottom - box.bottom))
    return stabilized


def remove_detached_specks(image: Image.Image) -> Image.Image:
    width, height = image.size
    pixels = image.load()
    seen = [[False] * width for _ in range(height)]
    components: list[list[tuple[int, int]]] = []

    for sy in range(height):
        for sx in range(width):
            if seen[sy][sx] or pixels[sx, sy][3] <= 0:
                continue
            q = deque([(sx, sy)])
            seen[sy][sx] = True
            component: list[tuple[int, int]] = []
            while q:
                x, y = q.popleft()
                component.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < width and 0 <= ny < height and not seen[ny][nx] and pixels[nx, ny][3] > 0:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            components.append(component)

    if len(components) <= 1:
        return image

    largest = max(components, key=len)
    for component in components:
        if component is largest or len(component) >= MIN_DETACHED_COMPONENT_AREA:
            continue
        for x, y in component:
            pixels[x, y] = (255, 255, 255, 0)
    return image


def save_contact_sheet(action_frames: dict[str, list[Path]], out_path: Path) -> None:
    thumbs: list[tuple[str, Image.Image]] = []
    for action, paths in action_frames.items():
        for index, path in enumerate(paths, start=1):
            img = Image.open(path).convert("RGBA")
            bg = Image.new("RGBA", img.size, (246, 246, 242, 255))
            bg.alpha_composite(img)
            bg.thumbnail((110, 130), Image.Resampling.LANCZOS)
            thumbs.append((f"{action} {index}", bg.convert("RGB")))

    if not thumbs:
        return
    cols = 8
    cell_w, cell_h = 130, 156
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (250, 250, 247))
    for idx, (_, thumb) in enumerate(thumbs):
        col = idx % cols
        row = idx // cols
        x = col * cell_w + (cell_w - thumb.width) // 2
        y = row * cell_h + 8
        sheet.paste(thumb, (x, y))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, quality=92)


def save_preview_gifs(action_frames: dict[str, list[Path]], manifest_actions: dict[str, dict], qa_dir: Path) -> None:
    qa_dir.mkdir(parents=True, exist_ok=True)
    for action, paths in action_frames.items():
        if not paths:
            continue
        fps = manifest_actions[action]["fps"]
        duration = max(20, int(round(1000 / fps)))
        frames = []
        for path in paths:
            img = Image.open(path).convert("RGBA")
            bg = Image.new("RGBA", img.size, (246, 246, 242, 255))
            bg.alpha_composite(img)
            frames.append(bg.convert("P", palette=Image.Palette.ADAPTIVE))
        frames[0].save(
            qa_dir / f"{action}.gif",
            save_all=True,
            append_images=frames[1:],
            duration=duration,
            loop=0 if manifest_actions[action]["loop"] else 1,
            optimize=False,
        )


def process_album(source_dir: Path, album_id: str, display_name: str, force: bool) -> dict:
    output_dir = RESOURCE_ROOT / album_id
    frames_dir = output_dir / "frames"
    qa_dir = QA_ROOT / album_id

    if output_dir.exists() and force:
        for path in sorted(output_dir.rglob("*"), reverse=True):
            if path.is_file():
                path.unlink()
            elif path.is_dir():
                path.rmdir()
    frames_dir.mkdir(parents=True, exist_ok=True)
    qa_dir.mkdir(parents=True, exist_ok=True)

    action_frames: dict[str, list[Path]] = {}
    manifest_actions: dict[str, dict] = {}
    raw_frames_by_file: dict[str, list[Image.Image]] = {}

    for file_name in ACTION_SPECS:
        sheet_path = source_dir / file_name
        if not sheet_path.exists():
            raise FileNotFoundError(f"缺少动作帧表: {sheet_path}")
        grid_layout = GRID_LAYOUT_OVERRIDES.get(album_id, {}).get(file_name)
        raw_frames_by_file[file_name] = extract_raw_frames(sheet_path, grid_layout)

    shared_content_extent = None
    if album_id in SHARED_SCALE_ALBUMS:
        all_raw_frames = [frame for frames in raw_frames_by_file.values() for frame in frames]
        shared_content_extent = measure_content_extent(all_raw_frames)

    for file_name, spec in ACTION_SPECS.items():
        raw_frames = raw_frames_by_file[file_name]
        scale_multiplier = ACTION_SCALE_OVERRIDES.get(album_id, {}).get(file_name, 1.0)
        frames = normalize_frames(raw_frames, scale_multiplier, shared_content_extent)
        action_id = spec["id"]
        prefix = spec["prefix"]
        saved_paths: list[Path] = []
        for index, frame in enumerate(frames, start=1):
            file = frames_dir / f"{album_id}_{prefix}_{index:04d}.png"
            frame.save(file, optimize=True)
            saved_paths.append(file)
        action_frames[action_id] = saved_paths
        relative_paths = [str(path.relative_to(ROOT / "Sources" / "JayPetApp" / "Resources")) for path in saved_paths]
        manifest_actions[action_id] = {
            "fps": spec["fps"],
            "frameDuration": round(1 / spec["fps"], 4),
            "loop": spec["loop"],
            "frameCount": len(saved_paths),
            "frames": relative_paths,
        }

    manifest = {
        "id": album_id,
        "displayName": display_name,
        "canvas": {"width": CANVAS_SIZE[0], "height": CANVAS_SIZE[1]},
        "source": str(source_dir),
        "actions": manifest_actions,
    }
    manifest_path = output_dir / f"{album_id}_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    save_contact_sheet(action_frames, qa_dir / "contact_sheet.jpg")
    save_preview_gifs(action_frames, manifest_actions, qa_dir / "gif")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="把专辑帧表切成桌宠可播放的透明帧")
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--album-id", default="jay")
    parser.add_argument("--display-name", default="Jay")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    manifest = process_album(args.source_dir, args.album_id, args.display_name, args.force)
    for action, info in manifest["actions"].items():
        print(f"{action}: {info['frameCount']} frames, {info['fps']} fps")
    print(f"manifest: {RESOURCE_ROOT / args.album_id / f'{args.album_id}_manifest.json'}")
    print(f"qa: {QA_ROOT / args.album_id}")


if __name__ == "__main__":
    main()
