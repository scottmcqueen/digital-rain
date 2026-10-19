# Digital Rain

A film-accurate "falling code" effect for macOS, built two ways:

- **[Web version](web/)**: a single HTML file using WebGL 2. Runs in any modern browser, and works as a
  live wallpaper with [Plash](https://sindresorhus.com/plash) or as a screen saver with
  [WebViewScreenSaver](https://github.com/liquidx/webviewscreensaver).
- **[Native screen saver](macos-screensaver/)**: a Swift `.saver` bundle rendering with Metal.

Both versions share the same simulation, shaders, settings and defaults, so they look the same and
their power use can be compared directly.

## What makes it look like the film

Most digital rain effects slide strings of text down the screen. In the film, glyphs mostly stay where
they are and flicker to new characters, while a bright cursor travels down each column and "writes" as
it goes, leaving a trail that fades behind it. This project models that directly:

- **Writing cursors** with a white-hot leading glyph, one or two per column at varied speeds.
- **Phosphor trails** that decay exponentially behind each cursor.
- **Mirrored half-width katakana**, numerals and a few symbols, in the spirit of the film's glyph set
  (the original custom glyph design isn't included).
- **Bloom** around bright glyphs, **screen door** grid, and a subtle vignette.

## Quick start

**Web:** open [`web/index.html`](web/index.html) in a browser. Press **S** for settings and
**Space** to pause. See the [web README](web/README.md) for URL options and wallpaper/screen saver setup.

**Screen saver:** on a Mac with the Command Line Tools installed (`xcode-select --install`):

```sh
cd macos-screensaver
./build.sh
```

Then choose **Digital Rain** in System Settings → Screen Saver. See the
[screen saver README](macos-screensaver/README.md) for details.

## Settings

Both versions have the same controls and defaults.

| Setting | Range | Default | What it does |
|---|---|---|---|
| Fall speed | 0.2–3× | 1× | How fast cursors travel down the columns |
| Glyph flicker | 0–4 per second | 0.8 | How often resting glyphs change character |
| Phosphor trail | 0.3–5 s | 1.6 s | How long a written glyph takes to fade |
| Rain density | 20–160% | 100% | How soon a column starts a new cursor |
| Glyph size | 10–44 | 18 | Glyph height in points (CSS pixels on the web) |
| Bloom | 0–2.5 | 1.1 | Strength of the glow around bright glyphs |
| Bloom spread | 0.5–3 | 1.3 | Width of the glow |
| Screen door | 0–100% | 35% | Strength of the fine pixel-grid overlay |
| Render resolution | 30–100% | 60% | Resolution the glyphs and bloom are drawn at |
| Frame rate | 24, 30, 60 fps | 30 fps | How often the effect redraws |
| Color | presets | Classic green | Rain color: Classic, Deep green, Cyan, Amber, Red, Violet, Pale |

## Performance

Both versions are designed to keep the GPU mostly idle: the CPU only moves the cursors, the GPU
computes fading and flicker, bloom runs at a quarter of the render resolution, and the effect redraws
only at the chosen frame rate. Measured on an M1 Max MacBook Pro, the web version adds roughly
250–300 mW of GPU power over the background load at full screen.

See [docs/performance.md](docs/performance.md) for the measurement method, results and findings, and
[docs/how-it-works.md](docs/how-it-works.md) for the rendering design.

## Requirements

- **Web:** a browser with WebGL 2 (Safari 15+, Chrome, Firefox, Edge). Glyphs use the Hiragino font
  on macOS and fall back to other Japanese fonts elsewhere.
- **Screen saver:** macOS 13 Ventura or later on Apple silicon, plus the Xcode Command Line Tools to build.

## License

[MIT](LICENSE)
