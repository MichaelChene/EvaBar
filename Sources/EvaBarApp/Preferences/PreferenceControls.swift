import AppKit

@MainActor
final class PreferenceTile: NSButton {
    var selected = false { didSet { needsDisplay = true } }
    var filled = true

    override func draw(_ dirtyRect: NSRect) {
        if filled {
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let fill = NSColor(white: dark ? 0.25 : 0.87, alpha: isEnabled ? 1 : 0.5)
            fill.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
        }
        if selected {
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            border.lineWidth = 2
            border.stroke()
        }
        super.draw(dirtyRect)
    }
}

@MainActor
final class ControlBand: NSStackView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.17).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        super.draw(dirtyRect)
    }
}

@MainActor
final class SeparatorPicker: NSPopUpButton {
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        NSColor(white: dark ? 0.25 : 0.87, alpha: 1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()

        let text = NSAttributedString(string: titleOfSelectedItem ?? "", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.85)
        ])
        text.draw(at: NSPoint(x: bounds.minX + 8, y: bounds.midY - text.size().height / 2))
        let x = bounds.maxX - 12
        let y = bounds.midY
        let tipOffset: CGFloat = isFlipped ? 1.5 : -1.5
        let chevron = NSBezierPath()
        chevron.move(to: NSPoint(x: x - 3, y: y - tipOffset))
        chevron.line(to: NSPoint(x: x, y: y + tipOffset))
        chevron.line(to: NSPoint(x: x + 3, y: y - tipOffset))
        chevron.lineWidth = 1
        NSColor.labelColor.withAlphaComponent(0.55).setStroke()
        chevron.stroke()
    }
}

@MainActor
final class StartupSwitch: NSButton {
    private let trackLayer = CALayer()
    private let thumbLayer = CALayer()
    private var showsOn = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        trackLayer.borderWidth = 1
        trackLayer.borderColor = NSColor(white: 0.62, alpha: 0.35).cgColor
        thumbLayer.backgroundColor = NSColor(white: 0.8, alpha: 1).cgColor
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(thumbLayer)
    }

    required init?(coder: NSCoder) { nil }

    func updateState(_ newState: NSControl.StateValue, animated: Bool) {
        allowsMixedState = newState == .mixed
        state = newState
        showsOn = newState != .off
        updateLayers(animated: animated && window?.isVisible == true
                     && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    override func layout() {
        super.layout()
        updateLayers()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayers()
    }

    // The layers supply the switch artwork while NSButton handles interaction.
    override func draw(_ dirtyRect: NSRect) {}

    private func updateLayers(animated: Bool = false) {
        guard bounds.width > 3, bounds.height > 3 else { return }
        let track = bounds.insetBy(dx: 0.5, dy: 0.5)
        let diameter = track.height - 2
        let inset = 1 + diameter / 2
        let position = CGPoint(x: showsOn ? track.maxX - inset : track.minX + inset, y: track.midY)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = track
        trackLayer.cornerRadius = track.height / 2
        thumbLayer.bounds.size = CGSize(width: diameter, height: diameter)
        thumbLayer.cornerRadius = diameter / 2

        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color = (showsOn ? NSColor.controlAccentColor : NSColor(white: 0.24, alpha: 0.75)).cgColor
            if trackLayer.backgroundColor != color {
                let previous = trackLayer.presentation()?.backgroundColor ?? trackLayer.backgroundColor
                trackLayer.backgroundColor = color
                transition(trackLayer, keyPath: "backgroundColor", from: previous, animated: animated)
            }
        }
        if thumbLayer.position != position {
            let previous = thumbLayer.presentation()?.position ?? thumbLayer.position
            thumbLayer.position = position
            transition(thumbLayer, keyPath: "position", from: previous, animated: animated)
        }
        CATransaction.commit()
    }

    private func transition(_ layer: CALayer, keyPath: String, from value: Any?, animated: Bool) {
        guard animated, let value else {
            layer.removeAnimation(forKey: keyPath)
            return
        }
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = value
        animation.duration = 0.2
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: keyPath)
    }
}

@MainActor
final class ShortcutEditorButton: NSButton {
    private let tokenFont = NSFont.systemFont(ofSize: 14, weight: .medium)
    var tokens: [String] = [] {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        guard !tokens.isEmpty else {
            return NSSize(width: max(110, super.intrinsicContentSize.width), height: 34)
        }
        let width = tokens.reduce(CGFloat(6)) { $0 + keyWidth($1) + 4 }
        return NSSize(width: width, height: 34)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !tokens.isEmpty else {
            super.draw(dirtyRect)
            return
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: tokenFont,
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.9)
        ]
        var x: CGFloat = 5
        for token in tokens {
            let width = keyWidth(token)
            let key = NSRect(x: x, y: bounds.midY - 12, width: width, height: 24)
            (NSColor(named: "hotkey.token.fill") ?? .controlColor).setFill()
            NSBezierPath(roundedRect: key, xRadius: 4, yRadius: 4).fill()
            let text = NSAttributedString(string: token, attributes: attributes)
            let size = text.size()
            text.draw(at: NSPoint(x: key.midX - size.width / 2, y: key.midY - size.height / 2))
            x += width + 4
        }
    }

    private func keyWidth(_ token: String) -> CGFloat {
        let width = (token as NSString).size(withAttributes: [.font: tokenFont]).width
        return max(24, ceil(width) + 10)
    }
}
