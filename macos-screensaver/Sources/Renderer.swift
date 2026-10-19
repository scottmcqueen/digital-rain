import Metal
import MetalKit
import CoreText
import QuartzCore

private struct SceneU {
    var color: SIMD4<Float>
    var grid: SIMD2<Float>
    var atlasGrid: SIMD2<Float>
    var time: Float
    var trail: Float
    var flicker: Float
    var ng: Float
}

private struct CompU {
    var bloom: Float
    var door: Float
    var doorPx: Float
    var pad: Float = 0
}

final class RainRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pScene: MTLRenderPipelineState
    private let pDown: MTLRenderPipelineState
    private let pBlur: MTLRenderPipelineState
    private let pComp: MTLRenderPipelineState
    private let atlas: MTLTexture
    private let glyphCount: Int
    private let atlasRows: Int
    private static let atlasCols = 10

    // Three state textures in rotation so the CPU never writes one the GPU is still reading.
    private var states: [MTLTexture] = []
    private var stateIndex = 0
    private let inflight = DispatchSemaphore(value: 3)
    private var sceneTex: MTLTexture?
    private var bloomA: MTLTexture?
    private var bloomB: MTLTexture?

    var settings: RainSettings { didSet { settingsChanged(from: oldValue) } }
    var sizeScale: Float = 1      // shrinks glyphs in the small System Settings preview
    var paused = false

    // Simulation: glyphs stay put; a cursor writes down each column.
    // The CPU only moves cursors and stamps when each cell was written; the GPU does the rest.
    private struct Drop { var y: Float = 0; var v: Float = 1; var li: Int = -1 }
    private var cols = 0, rows = 0
    private var state: [Float] = []
    private var drops: [[Drop]] = []
    private var simT: Float = 0
    private var lastTime: CFTimeInterval = 0
    private var viewSize = CGSize.zero
    private var drawableSize = CGSize.zero

    init?(device: MTLDevice, settings: RainSettings) {
        self.device = device
        guard let q = device.makeCommandQueue() else { return nil }
        queue = q
        self.settings = settings
        do {
            let lib = try device.makeLibrary(source: rainShaderSource, options: nil)
            func pipe(_ fn: String, _ fmt: MTLPixelFormat) throws -> MTLRenderPipelineState {
                let d = MTLRenderPipelineDescriptor()
                d.vertexFunction = lib.makeFunction(name: "vfull")
                d.fragmentFunction = lib.makeFunction(name: fn)
                d.colorAttachments[0].pixelFormat = fmt
                return try device.makeRenderPipelineState(descriptor: d)
            }
            pScene = try pipe("fscene", .rgba8Unorm)
            pDown = try pipe("fdown", .rgba8Unorm)
            pBlur = try pipe("fblur", .rgba8Unorm)
            pComp = try pipe("fcomp", .bgra8Unorm)
        } catch {
            NSLog("DigitalRain: shader setup failed: \(error)")
            return nil
        }
        let glyphs = RainRenderer.glyphList()
        glyphCount = glyphs.count
        atlasRows = (glyphs.count + RainRenderer.atlasCols - 1) / RainRenderer.atlasCols
        guard let a = RainRenderer.makeAtlas(device: device, queue: q, glyphs: glyphs,
                                             cols: RainRenderer.atlasCols, rows: atlasRows) else { return nil }
        atlas = a
        super.init()
    }

    // MARK: Glyph atlas (mirrored half-width katakana, numerals, a few symbols)

    private static func glyphList() -> [String] {
        var g: [String] = []
        for c in UInt32(0xFF66)...UInt32(0xFF9D) {
            if let u = UnicodeScalar(c) { g.append(String(Character(u))) }
        }
        for ch in "0123456789Z:.=\"*+-<>¦|" { g.append(String(ch)) }
        return g
    }

    private static func makeAtlas(device: MTLDevice, queue: MTLCommandQueue, glyphs: [String],
                                  cols: Int, rows: Int) -> MTLTexture? {
        let gw = 48, gh = 64, w = cols * gw, h = rows * gh
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setShouldAntialias(true)
        ctx.setAllowsFontSmoothing(false)
        let font = CTFontCreateWithName("HiraKakuProN-W3" as CFString, 50, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
        ]
        for (i, g) in glyphs.enumerated() {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: g, attributes: attrs))
            var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &asc, &desc, &lead))
            let cx = CGFloat((i % cols) * gw) + CGFloat(gw) / 2
            let cy = CGFloat(h) - (CGFloat((i / cols) * gh) + CGFloat(gh) / 2)   // bitmap row 0 is the top
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            if !(g.first?.isNumber ?? false) { ctx.scaleBy(x: -1, y: 1) }
            ctx.textPosition = CGPoint(x: -width / 2, y: -(asc - desc) / 2 - 2)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }
        guard let data = ctx.data else { return nil }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: w, height: h, mipmapped: true)
        td.usage = .shaderRead
        guard let tex = device.makeTexture(descriptor: td) else { return nil }
        tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: data, bytesPerRow: w)
        if let cb = queue.makeCommandBuffer(), let blit = cb.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: tex)
            blit.endEncoding()
            cb.commit()
            cb.waitUntilCompleted()
        }
        return tex
    }

    // MARK: Simulation

    private func spawn(_ d: inout Drop, initial: Bool) {
        d.v = 0.55 + Float.random(in: 0..<0.9)
        let r = Float(rows)
        d.y = initial ? Float.random(in: 0..<1) * r * 2 - r
                      : -Float.random(in: 0..<1) * r * (1.6 / Float(settings.density)) - 1
    }

    private func regrid() {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        let size = max(4, Float(settings.size) * sizeScale)
        cols = max(4, Int((Float(viewSize.width) / (size * 0.78)).rounded(.up)))
        rows = max(4, Int((Float(viewSize.height) / size).rounded(.up)))
        state = [Float](repeating: 0, count: cols * rows * 2)
        for i in 0..<(cols * rows) { state[i * 2] = -1e4 }
        drops = []
        for _ in 0..<cols {
            var list = [Drop()]
            if Float.random(in: 0..<1) < 0.35 { list.append(Drop()) }
            for j in list.indices { spawn(&list[j], initial: true) }
            drops.append(list)
        }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: cols, height: rows, mipmapped: false)
        td.usage = .shaderRead
        states = (0..<3).compactMap { _ in device.makeTexture(descriptor: td) }
        for _ in 0..<90 { step(1 / 30) }
    }

    private func step(_ dt: Float) {
        simT += dt
        if simT > 3000 {
            simT -= 3000
            var i = 0
            while i < state.count { state[i] -= 3000; i += 2 }
        }
        let rate = 16 * Float(settings.speed)
        for c in 0..<cols {
            for j in drops[c].indices {
                var d = drops[c][j]
                if d.li >= 0 { state[d.li * 2 + 1] = 0; d.li = -1 }
                let v = rate * d.v
                let prev = Int(d.y.rounded(.down))
                d.y += v * dt
                let cur = Int(d.y.rounded(.down))
                let lo = max(0, prev + 1), hi = min(rows - 1, cur)
                if lo <= hi {
                    for r in lo...hi { state[(r * cols + c) * 2] = simT - (d.y - Float(r)) / v }
                }
                if cur >= 0 && cur < rows {
                    let i = cur * cols + c
                    state[i * 2] = simT; state[i * 2 + 1] = 1; d.li = i
                }
                if d.y > Float(rows) + 1 { spawn(&d, initial: false) }
                drops[c][j] = d
            }
        }
    }

    // MARK: Targets

    private func makeTargets() {
        guard drawableSize.width > 0, drawableSize.height > 0 else { return }
        let sw = max(1, Int((drawableSize.width * CGFloat(settings.scale)).rounded()))
        let sh = max(1, Int((drawableSize.height * CGFloat(settings.scale)).rounded()))
        let bw = max(1, sw / 4), bh = max(1, sh / 4)
        func target(_ w: Int, _ h: Int) -> MTLTexture? {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
            d.usage = [.renderTarget, .shaderRead]
            d.storageMode = .private
            return device.makeTexture(descriptor: d)
        }
        sceneTex = target(sw, sh)
        bloomA = target(bw, bh)
        bloomB = target(bw, bh)
    }

    private func settingsChanged(from old: RainSettings) {
        if settings.size != old.size { regrid() }
        if settings.scale != old.scale { makeTargets() }
    }

    // MARK: MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSize = size
        viewSize = view.bounds.size
        makeTargets()
        regrid()
    }

    func draw(in view: MTKView) {
        if view.drawableSize != drawableSize || view.bounds.size != viewSize || sceneTex == nil {
            drawableSize = view.drawableSize
            viewSize = view.bounds.size
            makeTargets()
            regrid()
        }
        guard cols > 0, !states.isEmpty, let scene = sceneTex, let bA = bloomA, let bB = bloomB else { return }

        let now = CACurrentMediaTime()
        let dt: Float = lastTime == 0 ? 1 / 30 : Float(min(0.1, now - lastTime))
        lastTime = now
        if !paused { step(dt) }

        inflight.wait()
        stateIndex = (stateIndex + 1) % states.count
        let st = states[stateIndex]
        state.withUnsafeBytes { raw in
            st.replace(region: MTLRegionMake2D(0, 0, cols, rows), mipmapLevel: 0,
                       withBytes: raw.baseAddress!, bytesPerRow: cols * 8)
        }
        guard let cb = queue.makeCommandBuffer() else { inflight.signal(); return }
        let sem = inflight
        cb.addCompletedHandler { _ in sem.signal() }

        func pass(_ target: MTLTexture, _ pipe: MTLRenderPipelineState, _ setup: (MTLRenderCommandEncoder) -> Void) {
            let d = MTLRenderPassDescriptor()
            d.colorAttachments[0].texture = target
            d.colorAttachments[0].loadAction = .dontCare
            d.colorAttachments[0].storeAction = .store
            guard let e = cb.makeRenderCommandEncoder(descriptor: d) else { return }
            e.setRenderPipelineState(pipe)
            setup(e)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            e.endEncoding()
        }

        // Glyph scene
        var su = SceneU(color: settings.rgb,
                        grid: SIMD2(Float(cols), Float(rows)),
                        atlasGrid: SIMD2(Float(RainRenderer.atlasCols), Float(atlasRows)),
                        time: simT, trail: Float(settings.trail), flicker: Float(settings.flicker),
                        ng: Float(glyphCount))
        pass(scene, pScene) { e in
            e.setFragmentBytes(&su, length: MemoryLayout<SceneU>.stride, index: 0)
            e.setFragmentTexture(st, index: 0)
            e.setFragmentTexture(atlas, index: 1)
        }

        // Bloom at quarter resolution
        if settings.bloom > 0 {
            var texel = SIMD2<Float>(1 / Float(scene.width), 1 / Float(scene.height))
            pass(bA, pDown) { e in
                e.setFragmentBytes(&texel, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
                e.setFragmentTexture(scene, index: 0)
            }
            for k: Float in [1, 2.2] {
                let s = Float(settings.spread) * k
                var h = SIMD2<Float>(s / Float(bA.width), 0)
                pass(bB, pBlur) { e in
                    e.setFragmentBytes(&h, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
                    e.setFragmentTexture(bA, index: 0)
                }
                var v = SIMD2<Float>(0, s / Float(bA.height))
                pass(bA, pBlur) { e in
                    e.setFragmentBytes(&v, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
                    e.setFragmentTexture(bB, index: 0)
                }
            }
        }

        // Composite: bloom, screen door, vignette, tone map
        guard let rpd = view.currentRenderPassDescriptor, let drawable = view.currentDrawable else {
            cb.commit(); return
        }
        rpd.colorAttachments[0].loadAction = .dontCare
        let pxPerPt = viewSize.width > 0 ? Float(drawableSize.width / viewSize.width) : 2
        var cu = CompU(bloom: Float(settings.bloom), door: Float(settings.door),
                       doorPx: max(2, (pxPerPt * 1.5).rounded()))
        if let e = cb.makeRenderCommandEncoder(descriptor: rpd) {
            e.setRenderPipelineState(pComp)
            e.setFragmentBytes(&cu, length: MemoryLayout<CompU>.stride, index: 0)
            e.setFragmentTexture(scene, index: 0)
            e.setFragmentTexture(bA, index: 1)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            e.endEncoding()
        }
        cb.present(drawable)
        cb.commit()
    }
}
