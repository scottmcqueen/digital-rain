# How it works

Both versions follow the same design. The web version uses WebGL 2 and the screen saver uses Metal, but
the simulation, shader passes and constants match.

## Simulation

The screen is a grid of glyph cells. Each column has one or two **cursors**, each with its own speed.
Every frame, a cursor moves down and stamps the current time on each cell it passes. The cell under the
cursor is flagged as the **leading glyph**. When a cursor leaves the bottom, it restarts above the top
after a random delay that depends on the rain density setting.

The CPU stores only two values per cell: the time it was last written and the leading-glyph flag. Its
work per frame scales with the number of columns, not the number of cells. The whole grid is uploaded
to the GPU each frame as a small floating-point texture (two 32-bit values per cell).

Earlier, the CPU also faded every cell and rolled a random number per cell per frame for flicker. Moving
that work to the GPU cut the web version's renderer CPU from about 8.4% to 5.6%.

## Glyph scene pass

A single full-screen pass draws every cell. For each pixel, the fragment shader:

1. Finds its cell and reads the cell's write time and leading flag.
2. Computes brightness as `exp(-(now - writeTime) / trail)`, the phosphor fade.
3. Chooses the glyph with a hash of the cell position and a time-based counter, so glyphs flicker at a
   per-cell rate without any stored state. A glyph also changes when it is rewritten, and the leading
   glyph cycles quickly.
4. Samples the glyph from a texture atlas, using explicit gradients so mipmapping doesn't cause seams at
   cell edges.
5. Colors trails with the chosen color (brightness raised to the power 1.7) and the leading glyph near
   white.

This pass renders at the **render resolution** setting (60% of native by default).

## Glyph atlas

At startup, the glyphs are drawn once into a grayscale texture with mipmaps: 56 half-width katakana
(U+FF66 to U+FF9D), mirrored horizontally, plus digits (not mirrored) and a few symbols. The font is
Hiragino Kaku Gothic ProN.

## Bloom

1. Downsample the scene to a quarter of the render resolution with a four-tap box filter.
2. Blur horizontally, then vertically, with a nine-tap Gaussian.
3. Repeat the blur once with 2.2 times the spread for a softer, wider halo.

Because a glow is soft, quarter resolution looks almost identical to full resolution at a fraction of
the cost.

## Composite pass

Runs at native resolution so the screen door stays crisp:

1. Adds the bloom to the scene.
2. Darkens a fine grid aligned to physical pixels (about 1.5 points per cell) to create the screen door.
3. Applies a subtle vignette.
4. Tone-maps with `1 - exp(-1.9 * color)` so bright areas roll off smoothly instead of clipping.

## Frame pacing

Both versions draw only at the chosen frame rate rather than the display's refresh rate (up to 120 Hz on
ProMotion displays):

- **Web:** a timer schedules each frame at the chosen rate, and each draw waits for the next display
  refresh. Pausing, or hiding the page, stops drawing entirely.
- **Screen saver:** the `MTKView` is paused and drawn only from `animateOneFrame`, which macOS calls at
  the frame rate set in `animationTimeInterval`. Three state textures rotate so the CPU never overwrites
  one the GPU is still reading.
