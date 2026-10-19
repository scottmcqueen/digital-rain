import AppKit

/// The Options sheet shown from System Settings > Screen Saver.
/// Changes preview live; Done saves them, Cancel restores what was there before.
final class ConfigSheet: NSObject {
    let window: NSWindow
    private var settings: RainSettings
    private let original: RainSettings
    private let onChange: (RainSettings, Bool) -> Void
    private var sliders: [NSSlider] = []
    private var valueLabels: [NSTextField] = []
    private let colorPopup = NSPopUpButton()
    private let fpsPopup = NSPopUpButton()
    private static let fpsOptions = [24, 30, 60]

    private struct Control {
        let label: String
        let min: Double
        let max: Double
        let path: WritableKeyPath<RainSettings, Double>
        let format: (Double) -> String
    }

    private static let controls: [Control] = [
        Control(label: "Fall speed", min: 0.2, max: 3, path: \.speed, format: { String(format: "%.2f×", $0) }),
        Control(label: "Glyph flicker", min: 0, max: 4, path: \.flicker, format: { String(format: "%.2f/s", $0) }),
        Control(label: "Phosphor trail", min: 0.3, max: 5, path: \.trail, format: { String(format: "%.1f s", $0) }),
        Control(label: "Rain density", min: 0.2, max: 1.6, path: \.density, format: { "\(Int(($0 * 100).rounded()))%" }),
        Control(label: "Glyph size", min: 10, max: 44, path: \.size, format: { "\(Int($0.rounded())) pt" }),
        Control(label: "Bloom", min: 0, max: 2.5, path: \.bloom, format: { String(format: "%.2f", $0) }),
        Control(label: "Bloom spread", min: 0.5, max: 3, path: \.spread, format: { String(format: "%.2f", $0) }),
        Control(label: "Screen door", min: 0, max: 1, path: \.door, format: { "\(Int(($0 * 100).rounded()))%" }),
        Control(label: "Render resolution", min: 0.3, max: 1, path: \.scale, format: { "\(Int(($0 * 100).rounded()))%" })
    ]

    init(settings: RainSettings, onChange: @escaping (RainSettings, Bool) -> Void) {
        self.settings = settings
        self.original = settings
        self.onChange = onChange
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                          styleMask: [.titled], backing: .buffered, defer: true)
        super.init()
        build()
    }

    private func build() {
        var rows: [[NSView]] = []
        for (i, c) in Self.controls.enumerated() {
            let label = NSTextField(labelWithString: c.label)
            let slider = NSSlider(value: settings[keyPath: c.path], minValue: c.min, maxValue: c.max,
                                  target: self, action: #selector(sliderChanged(_:)))
            slider.tag = i
            slider.isContinuous = true
            slider.widthAnchor.constraint(equalToConstant: 190).isActive = true
            let value = NSTextField(labelWithString: c.format(settings[keyPath: c.path]))
            value.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            value.textColor = .secondaryLabelColor
            value.widthAnchor.constraint(equalToConstant: 56).isActive = true
            sliders.append(slider)
            valueLabels.append(value)
            rows.append([label, slider, value])
        }

        RainSettings.presets.forEach { colorPopup.addItem(withTitle: $0.name) }
        colorPopup.target = self
        colorPopup.action = #selector(colorChanged)
        rows.append([NSTextField(labelWithString: "Color"), colorPopup, NSGridCell.emptyContentView])

        Self.fpsOptions.forEach { fpsPopup.addItem(withTitle: "\($0) fps") }
        fpsPopup.target = self
        fpsPopup.action = #selector(fpsChanged)
        rows.append([NSTextField(labelWithString: "Frame rate"), fpsPopup, NSGridCell.emptyContentView])

        let grid = NSGridView(views: rows)
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .lastBaseline

        let title = NSTextField(labelWithString: "Digital Rain")
        title.font = .boldSystemFont(ofSize: 15)

        let reset = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetTapped))
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancel.keyEquivalent = "\u{1b}"
        let done = NSButton(title: "Done", target: self, action: #selector(doneTapped))
        done.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let buttons = NSStackView(views: [reset, spacer, cancel, done])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [title, grid, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        buttons.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        window.contentView = content
        window.setContentSize(content.fittingSize)
        refresh()
    }

    private func refresh() {
        for (i, c) in Self.controls.enumerated() {
            sliders[i].doubleValue = settings[keyPath: c.path]
            valueLabels[i].stringValue = c.format(settings[keyPath: c.path])
        }
        let ci = RainSettings.presets.firstIndex { $0.hex.lowercased() == settings.color.lowercased() } ?? 0
        colorPopup.selectItem(at: ci)
        fpsPopup.selectItem(at: Self.fpsOptions.firstIndex(of: settings.fps) ?? 1)
    }

    @objc private func sliderChanged(_ slider: NSSlider) {
        let c = Self.controls[slider.tag]
        var v = slider.doubleValue
        if c.path == \RainSettings.size { v = v.rounded() }
        settings[keyPath: c.path] = v
        valueLabels[slider.tag].stringValue = c.format(v)
        onChange(settings, false)
    }

    @objc private func colorChanged() {
        settings.color = RainSettings.presets[colorPopup.indexOfSelectedItem].hex
        onChange(settings, false)
    }

    @objc private func fpsChanged() {
        settings.fps = Self.fpsOptions[fpsPopup.indexOfSelectedItem]
        onChange(settings, false)
    }

    @objc private func resetTapped() {
        settings = RainSettings()
        refresh()
        onChange(settings, false)
    }

    @objc private func cancelTapped() {
        onChange(original, false)
        close()
    }

    @objc private func doneTapped() {
        onChange(settings, true)
        close()
    }

    private func close() {
        if let parent = window.sheetParent { parent.endSheet(window) } else { window.close() }
    }
}
