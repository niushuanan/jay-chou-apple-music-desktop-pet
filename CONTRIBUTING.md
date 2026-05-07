# Contributing

## Development Setup

1. Install Xcode or the Swift 6.1 toolchain
2. Install Python 3
3. Install Pillow if you plan to regenerate assets

```bash
python3 -m pip install Pillow
```

## Local Checks

Validate resources:

```bash
cd app
python3 scripts/validate_resources.py
```

Build the app:

```bash
cd app
swift build
```

## Pull Request Notes

- Keep source paths and filenames in English
- When asset files change, rerun the validation script
- Include a short note describing whether the change affects code, assets, or both
