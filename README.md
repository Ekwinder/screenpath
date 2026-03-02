# ScreenPath

A macOS menu bar utility that tracks screenshot files and makes the latest screenshot easy to copy or drag into other apps.

## Install

```bash
brew tap Ekwinder/screenpath
brew install --cask screenpath
```

## Manual Install

Download the latest `ScreenPath.dmg` from GitHub Releases, open it, and drag `ScreenPath.app` into `Applications`.

## Open

This build is currently unsigned and not notarized. If macOS blocks it on first launch:

```bash
xattr -dr com.apple.quarantine /Applications/ScreenPath.app
```

Then open `ScreenPath.app` again.

## Usage

- Click the menu bar icon.
- Copy the latest screenshot path.
- Drag the latest screenshot into another app.
- Access recent screenshots from the menu.

## License

MIT
