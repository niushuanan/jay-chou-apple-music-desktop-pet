#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_ROOT = ROOT / "Sources" / "JayPetApp" / "Resources"
CONFIG_DIR = RESOURCE_ROOT / "config"
ALBUM_CONFIG = CONFIG_DIR / "albums.json"
TRACK_MAP = CONFIG_DIR / "track_album_map.json"
BUBBLE_RULES = CONFIG_DIR / "bubble_anchor_rules.json"
REQUIRED_ACTIONS = ("idle", "dragging", "enter", "exit")


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def fail(message: str) -> None:
    raise SystemExit(f"配置校验失败: {message}")


def manifest_path(raw_path: str) -> Path:
    path = RESOURCE_ROOT / raw_path
    if path.suffix != ".json":
        path = path.with_suffix(".json")
    return path


def validate_album(album: dict, known_ids: set[str]) -> tuple[int, int]:
    album_id = album.get("id")
    if not album_id:
        fail("专辑缺少 id")
    if album_id in known_ids:
        fail(f"专辑 id 重复: {album_id}")
    known_ids.add(album_id)

    for key in ("displayName", "aliases", "enabled", "bubbleLayout", "animationManifest"):
        if key not in album:
            fail(f"{album_id} 缺少字段: {key}")

    aliases = album["aliases"]
    if not isinstance(aliases, list) or not aliases:
        fail(f"{album_id} aliases 必须是非空数组")

    manifest_file = manifest_path(album["animationManifest"])
    if not manifest_file.exists():
        fail(f"{album_id} 找不到 manifest: {manifest_file}")

    manifest = load_json(manifest_file)
    actions = manifest.get("actions")
    if not isinstance(actions, dict):
        fail(f"{album_id} manifest 缺少 actions")

    frame_total = 0
    for action_name in REQUIRED_ACTIONS:
        action = actions.get(action_name)
        if not isinstance(action, dict):
            fail(f"{album_id} 缺少动作: {action_name}")
        frames = action.get("frames")
        if not isinstance(frames, list) or not frames:
            fail(f"{album_id}.{action_name} frames 必须是非空数组")
        for frame in frames:
            frame_path = RESOURCE_ROOT / frame
            if not frame_path.exists():
                fail(f"{album_id}.{action_name} 找不到帧: {frame}")
        frame_total += len(frames)

    return 1, frame_total


def validate_track_map(album_ids: set[str]) -> int:
    mapping = load_json(TRACK_MAP)
    if not isinstance(mapping, dict):
        fail("track_album_map必须是对象")
    for track, album_id in mapping.items():
        if album_id not in album_ids:
            fail(f"歌曲 {track} 指向未知专辑: {album_id}")
    return len(mapping)


def validate_bubble_rules(album_ids: set[str]) -> tuple[int, int]:
    rules = load_json(BUBBLE_RULES)
    album_rules = rules.get("albumRules", {})
    track_rules = rules.get("trackRules", {})
    if not isinstance(album_rules, dict) or not isinstance(track_rules, dict):
        fail("bubble_anchor_rules格式错误")
    for album_id in album_rules:
        if album_id not in album_ids:
            fail(f"气泡专辑规则指向未知专辑: {album_id}")
    return len(album_rules), len(track_rules)


def main() -> None:
    config = load_json(ALBUM_CONFIG)
    albums = config.get("albums")
    if not isinstance(albums, list) or not albums:
        fail("albums必须包含 albums")

    album_ids: set[str] = set()
    album_count = 0
    frame_total = 0
    for album in albums:
        count, frames = validate_album(album, album_ids)
        album_count += count
        frame_total += frames

    track_count = validate_track_map(album_ids)
    album_rule_count, track_rule_count = validate_bubble_rules(album_ids)
    print(
        "配置校验通过: "
        f"{album_count} 张专辑, "
        f"{frame_total} 个核心动作帧引用, "
        f"{track_count} 条歌曲映射, "
        f"{album_rule_count} 条专辑气泡规则, "
        f"{track_rule_count} 条歌曲气泡规则"
    )


if __name__ == "__main__":
    main()
