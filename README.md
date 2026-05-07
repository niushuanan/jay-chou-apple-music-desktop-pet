# Jay Chou Apple Music Desktop Pet

![App preview](docs/images/app-preview.png)

A native macOS desktop pet that reacts to the currently playing Jay Chou album in Apple Music.

The app maps Apple Music metadata to album-specific character art, swaps animation sets in real time, exposes playback controls from the desktop, and renders a lyric bubble that follows the pet window.

## Features

- Native macOS desktop pet built with SwiftPM and AppKit
- Album-aware character switching for 16 Jay Chou albums
- Apple Music playback controls through Apple Events
- Lyric bubble with album-specific anchor rules
- Included source art, animation sheets, processed resources, and validation scripts

## Repository Layout

```text
assets/
  album-character-concepts/      Original character concept PNGs
  animated-album-sheets/         Album animation sheets (idle / enter / exit / dragging)
app/
  Package.swift
  Sources/JayPetApp/             macOS application source
  Sources/JayPetApp/Resources/   Runtime resources and configuration
  scripts/                       Asset processing, validation, run, and packaging scripts
docs/
  images/app-preview.png
  product-brief-zh.md
```

## Requirements

- macOS 13 or newer
- Apple Music installed
- Swift 6.1 toolchain or Xcode with SwiftPM support
- Python 3.10+
- Pillow for asset processing scripts

Install the Python dependency when you want to regenerate processed art or animation manifests:

```bash
python3 -m pip install Pillow
```

## Quick Start

Build and run the app:

```bash
cd app
swift run JayPetApp
```

Run the resource integrity check:

```bash
cd app
python3 scripts/validate_resources.py
```

Use the convenience launcher:

```bash
cd app
./scripts/build_and_run.sh --verify
```

## Apple Music Permissions

The app talks to Apple Music through Apple Events and `osascript`.

On first launch, macOS may ask you to allow automation access for Apple Music. If playback state does not update:

1. Open `System Settings`
2. Go to `Privacy & Security`
3. Check `Automation`
4. Allow the app or Terminal to control `Music`

## Asset Workflow

Regenerate processed character art from the source concept images:

```bash
cd app
python3 scripts/process_album_art.py
```

Regenerate one album animation manifest and frame sequence:

```bash
cd app
python3 scripts/process_animation_sheets.py \
  --source-dir ../assets/animated-album-sheets/jay \
  --album-id jay \
  --display-name Jay \
  --force
```

The script writes runtime frames into `app/Sources/JayPetApp/Resources/album_animations/<album_id>/` and QA output into `app/build/animation_qa/`.

## Packaging

Build a local `.app` bundle into `~/Applications`:

```bash
cd app
./scripts/package_app.sh
```

## License

- Code in this repository is available under the [MIT License](LICENSE).
- Visual assets in `assets/` and `app/Sources/JayPetApp/Resources/` are available under [CC BY 4.0](LICENSE.assets).

See [NOTICE](NOTICE) for trademark and affiliation notes.
