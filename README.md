# Digital Rain screen saver (Metal)

A native macOS screen saver of the Matrix's iconic Digital Rain with the same rain, bloom, phosphor trails and screen door as the web version.

## Build and install

1. If you don't have Swift yet, run `xcode-select --install`.
2. In Terminal, from this folder, run `./build.sh`.
3. Open System Settings > Screen Saver and choose Digital Rain. Click Options to adjust it.

After rebuilding, run `./build.sh` again. It quits the screen saver host so the new version loads.

## Measure power

Select Digital Rain in System Settings first, then run `./measure.sh` and don't touch the mouse or keyboard
until the readings print. Move the mouse afterwards to dismiss the screen saver.

## Notes

- Shaders compile when the screen saver starts, so the build only needs the Command Line Tools.
- Since macOS Sonoma, the screen saver host can keep running after it's dismissed. This screen saver
  stops drawing and quits the host two seconds after it's told to stop.
- Built for Apple silicon (arm64).
