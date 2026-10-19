import Foundation
import ScreenSaver

/// Same settings and defaults as the web version, so measurements compare like for like.
struct RainSettings: Equatable {
    var speed: Double = 1
    var flicker: Double = 0.8
    var trail: Double = 1.6
    var density: Double = 1
    var size: Double = 18
    var bloom: Double = 1.1
    var spread: Double = 1.3
    var door: Double = 0.35
    var scale: Double = 0.6
    var fps: Int = 30
    var color: String = "#4cff7c"

    static let presets: [(name: String, hex: String)] = [
        ("Classic", "#4cff7c"), ("Deep green", "#14e64a"), ("Cyan", "#5ce1ff"),
        ("Amber", "#ffb347"), ("Red", "#ff4d5a"), ("Violet", "#b77dff"), ("Pale", "#e4ffe9")
    ]

    static let doubleKeys: [(String, WritableKeyPath<RainSettings, Double>)] = [
        ("speed", \.speed), ("flicker", \.flicker), ("trail", \.trail), ("density", \.density),
        ("size", \.size), ("bloom", \.bloom), ("spread", \.spread), ("door", \.door), ("scale", \.scale)
    ]

    private static func store() -> ScreenSaverDefaults? {
        let id = Bundle(for: DigitalRainView.self).bundleIdentifier ?? "local.digitalrain"
        return ScreenSaverDefaults(forModuleWithName: id)
    }

    static func load() -> RainSettings {
        var s = RainSettings()
        guard let d = store() else { return s }
        for (key, path) in doubleKeys where d.object(forKey: key) != nil {
            s[keyPath: path] = d.double(forKey: key)
        }
        if d.object(forKey: "fps") != nil { s.fps = d.integer(forKey: "fps") }
        if let c = d.string(forKey: "color") { s.color = c }
        return s
    }

    func save() {
        guard let d = Self.store() else { return }
        for (key, path) in Self.doubleKeys { d.set(self[keyPath: path], forKey: key) }
        d.set(fps, forKey: "fps")
        d.set(color, forKey: "color")
        d.synchronize()
    }

    var rgb: SIMD4<Float> {
        var hex = color.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        let v = UInt32(hex, radix: 16) ?? 0x4cff7c
        return SIMD4(Float((v >> 16) & 255) / 255, Float((v >> 8) & 255) / 255, Float(v & 255) / 255, 1)
    }
}
