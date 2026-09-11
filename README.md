# ScreenPath

A macOS menu bar utility that tracks screenshot files and makes the latest screenshot easy to copy or drag into other apps.

## Install

```bash
brew tap Ekwinder/screenpath https://github.com/Ekwinder/screenpath
brew install --cask screenpath
```

Homebrew now reads the cask directly from this repository.

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
- Use **Options → Choose Watched Folder…** to select and remember a different screenshot folder. The latest and recent previews update immediately.
- Use **Options → Use macOS Screenshot Folder** to return to following the system screenshot location (Desktop by default).

Changing the watched folder does not change where macOS saves screenshots. To save new screenshots in your chosen folder, press **Shift–Command–5 → Options → Other Location…** and select it.

## License

MIT
