# Performance

## How to measure

Activity Monitor's percentages are hard to compare between runs, because they depend on window size and
on how macOS splits work between processes. Power draw is a more reliable measure. Use macOS's built-in
`powermetrics`:

```sh
sudo powermetrics --samplers gpu_power,cpu_power -i 2000 -n 5 | grep -E "GPU HW active|GPU Power|CPU Power"
```

This prints five samples, two seconds apart. **GPU Power** in milliwatts is the main number to compare.

### Test routine

1. Run the effect **full screen** with the settings you want to test.
2. Close the settings panel and leave the mouse still.
3. Wait about 10 seconds, then run the command.
4. **Ignore samples taken while switching windows.** These show up as spikes of 1.2–1.5 W.
5. Take a **paused** reading (press Space on the web version) to measure the background load. The
   effect's own cost is the running reading minus the paused one.

For the screen saver, `macos-screensaver/measure.sh` does steps 1–3 automatically.

## Results

Measured in October 2026 on a 14-inch MacBook Pro with M1 Max, with other apps open.

### Web version (running full screen in the Claude desktop app)

| Test | Steady GPU power | GPU busy |
|---|---|---|
| Running, default settings (60% resolution, 30 fps) | about 455–470 mW | 31–38% |
| Paused (background load) | about 200 mW (varies 22–613 mW) | 9–43% |
| Running, 30% resolution | about 445 mW | 25–33% |
| Running, 30% resolution, settings panel open (frosted-glass version) | about 815 mW | 40–45% |

Renderer CPU in Activity Monitor dropped from 8.4% to 5.6% after fading and flicker moved to the GPU.

### Native screen saver (Metal)

Not yet measured. Add results here from `measure.sh`.

## Findings

- **The effect itself costs roughly 250–300 mW of GPU power** above background load at full screen.
- **Render resolution barely matters.** Halving it saved about 25 mW, within measurement noise. Drawing
  the glyphs and bloom is cheap, so resolution can be chosen by how sharp the glyphs look.
- **Per-frame costs dominate.** Most of the cost is paid once per frame regardless of resolution: the
  full-resolution composite pass, and the browser and WindowServer compositing a full-screen window.
  Lowering the frame rate is the main way to reduce power.
- **Blurring over animated content is expensive.** The settings panel originally used a frosted-glass
  background, which forced the GPU to re-blur the moving rain every frame and added about 350 mW.
  Replacing it with a solid translucent background removed that cost.
- **Running natively should remove the browser layer.** The Metal screen saver skips the browser's
  compositing step, which is why it's worth measuring separately.
