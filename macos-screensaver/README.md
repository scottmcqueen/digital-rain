git add -A
git status# Digital Rain: native screen saver (Metal)

A macOS screen saver bundle (`DigitalRain.saver`) written in Swift and rendered with Metal. It uses the
same simulation, shader passes, settings and defaults as the web version.

> **Status:** first version. It has not yet been built on a Mac, so the first build may need small fixes.
> Please open an issue with the Terminal output if it fails to build.

## Requirements

- macOS 13 Ventura or later
- Apple silicon (the build targets arm64)
- Xcode Command Line Tools: `xcode-select --install` (the full Xcode app isn't needed)

## Build and install

```sh
./build.sh
```

The script:

1. Compiles the Swift sources into `build/DigitalRain.saver`.
2. Signs the bundle for local use (ad-hoc signature).
3. Copies it to `~/Library/Screen Savers/`.
4. Quits the screen saver host and System Settings so the new build is loaded.

Then open **System Settings → Screen Saver**, choose **Digital Rain**, and click **Options** to adjust
it. Changes preview live; **Done** saves them and **Cancel** restores the previous settings.

Run `./build.sh` again after any change to rebuild and reinstall.

## Measure power use

1. Select Digital Rain in System Settings → Screen Saver.
2. Run `./measure.sh` and enter your password when asked.
3. Don't touch the mouse or keyboard for about 25 seconds. The script starts the screen saver, waits
   for it to settle, then samples GPU and CPU power with `powermetrics`.
4. Move the mouse to dismiss the screen saver and read the results.

Add results to [../docs/performance.md](../docs/performance.md) to compare with the web version.

## Uninstall

```sh
rm -rf ~/Library/Screen\ Savers/DigitalRain.saver
killall legacyScreenSaver 2>/dev/null
```

## Files

| File | Purpose |
|---|---|
| `Sources/DigitalRainView.swift` | The `ScreenSaverView` subclass: hosts the Metal view, paces frames, handles the host's stop signal |
| `Sources/Renderer.swift` | Simulation, glyph atlas, render targets and the Metal passes |
| `Sources/Shaders.swift` | Metal shader source, compiled when the screen saver starts |
| `Sources/ConfigSheet.swift` | The Options sheet |
| `Sources/Settings.swift` | Settings, defaults and storage |
| `Info.plist` | Bundle metadata |
| `build.sh` | Build, sign and install |
| `measure.sh` | Start the screen saver and sample power |

## Known macOS behavior

Since macOS Sonoma, third-party screen savers run inside a host process called `legacyScreenSaver`,
which can keep running after the screen saver is dismissed. Digital Rain stops drawing when macOS
signals that the screen saver is stopping, then quits the host two seconds later so it doesn't keep
using power in the background. The preview in System Settings isn't affected.

Settings are stored with `ScreenSaverDefaults`, which places them in the screen saver host's container
under `~/Library/Containers/`.
