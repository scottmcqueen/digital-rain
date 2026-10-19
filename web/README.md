# Digital Rain: web version

A single self-contained HTML file (`index.html`) rendering the effect with WebGL 2. No build step and no
external files.

## Controls

| Key | Action |
|---|---|
| **S** | Open or close settings |
| **Space** | Pause or resume (a paused page stops drawing entirely) |
| **Esc** | Close settings |

The settings button appears in the top-right corner when you move the mouse and fades out after a few
seconds. Settings are saved in the browser's local storage for that page.

## URL options

Any setting can be passed in the page's address, which overrides saved settings. This is how the
wallpaper and screen saver apps below pick up your settings.

| Parameter | Example | Notes |
|---|---|---|
| `speed` | `speed=1.5` | Fall speed multiplier |
| `flicker` | `flicker=0.8` | Glyph changes per second |
| `trail` | `trail=1.6` | Fade time in seconds |
| `density` | `density=1` | Rain density, 1 = 100% |
| `size` | `size=18` | Glyph size in CSS pixels |
| `bloom` | `bloom=1.1` | Bloom strength |
| `spread` | `spread=1.3` | Bloom width |
| `door` | `door=0.35` | Screen door strength, 0–1 |
| `scale` | `scale=0.6` | Render resolution, 0.3–1 |
| `fps` | `fps=30` | Frame rate cap |
| `color` | `color=4cff7c` | Hex color, without the `#` |
| `ui` | `ui=0` | Hides the settings button and status messages |

The **Screensaver link** box in the settings panel builds this query string from your current
settings, with `ui=0` included.

Example: `index.html?speed=1.2&color=5ce1ff&bloom=1.4&ui=0`

## Use as a live wallpaper (Plash)

[Plash](https://sindresorhus.com/plash) is a free Mac App Store app that shows a web page as your
desktop wallpaper.

1. Open Plash and choose **Add Website**.
2. Enter the page's address with your settings query and `ui=0` appended. Use the GitHub Pages
   address (below) or a local file path such as `file:///Users/you/digital-rain/web/index.html?ui=0`.

## Use as a screen saver (WebViewScreenSaver)

[WebViewScreenSaver](https://github.com/liquidx/webviewscreensaver) is an open-source screen saver that
shows a web page.

1. Install it, then select it in System Settings → Screen Saver and click **Options**.
2. Add the page's address with your settings query and `ui=0` appended.

For lower power use as a screen saver, see the [native Metal version](../macos-screensaver/).

## Host it with GitHub Pages

To get a public address for Plash or WebViewScreenSaver, enable GitHub Pages for this repository
(Settings → Pages → Deploy from branch → `main`, folder `/ (root)`). The page is then served at:

```
https://<your-username>.github.io/digital-rain/web/
```

## Power tips

- **Frame rate** is the biggest lever: costs that don't depend on resolution are paid on every frame.
- **Render resolution** barely affects power in testing, so set it by how sharp you want the glyphs.
- **Close the settings panel** when you're not adjusting things.

See [../docs/performance.md](../docs/performance.md) for measurements.
