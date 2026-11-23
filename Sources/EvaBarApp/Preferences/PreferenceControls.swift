import AppKit
import Carbon.HIToolbox

@MainActor
final class PreferenceTile: NSButton {
    var selected = false {
        didSet {
            setAccessibilitySelected(selected)
            needsDisplay = true
        }
    }
    var filled = true
    let glassBackground = LiquidGlassBackground(cornerRadius: 8)

    override var isEnabled: Bool {
        didSet { glassBackground.alphaValue = isEnabled ? 1 : 0.45 }
    }

    func updateLiquidGlass(_ enabled: Bool) {
        glassBackground.update(enabled: enabled)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if filled && glassBackground.isHidden {
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let fill = NSColor(white: dark ? 0.25 : 0.87, alpha: isEnabled ? 1 : 0.5)
            fill.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
        }
        if selected {
            NSColor.controlAccentColor.setStroke()
            let radius: CGFloat = glassBackground.isHidden ? 6 : 7
            let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius)
            border.lineWidth = 2
            border.stroke()
        }
        super.draw(dirtyRect)
    }
}

@MainActor
final class ControlBand: NSStackView {
    private let glassBackground = LiquidGlassBackground(cornerRadius: 12)

    func updateLiquidGlass(_ enabled: Bool) {
        if enabled && glassBackground.superview == nil {
            glassBackground.frame = bounds
            addSubview(glassBackground, positioned: .below, relativeTo: nil)
        }
        glassBackground.update(enabled: enabled)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if glassBackground.isHidden {
            NSColor.black.withAlphaComponent(0.17).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        }
        super.draw(dirtyRect)
    }
}

@MainActor
final class PreferencePicker: NSPopUpButton {
    weak var dropdownMenu: DropdownMenu?
    private let glassBackground = LiquidGlassBackground(cornerRadius: 12.5)
    private static let classicTitleInset: CGFloat = 8

    func sizedView(width: CGFloat = 130) -> NSView {
        let height: CGFloat = 25
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        // Size the custom bezel independently of the popup cell's alignment rectangle.
        for view in [glassBackground as NSView, self] {
            view.frame = container.bounds
            view.autoresizingMask = [.width, .height]
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: width),
            container.heightAnchor.constraint(equalToConstant: height)
        ])
        return container
    }

    func updateLiquidGlass(_ enabled: Bool) {
        glassBackground.update(enabled: enabled)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if !openDropdown() { super.mouseDown(with: event) }
    }

    override func performClick(_ sender: Any?) {
        if !openDropdown() { super.performClick(sender) }
    }

    override func accessibilityPerformPress() -> Bool {
        openDropdown() || super.accessibilityPerformPress()
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        if modifiers.isEmpty {
            switch Int(event.keyCode) {
            case kVK_Space, kVK_Return, kVK_ANSI_KeypadEnter, kVK_UpArrow, kVK_DownArrow:
                if openDropdown() { return }
            default: break
            }
        }
        super.keyDown(with: event)
    }

    private func openDropdown() -> Bool {
        guard LiquidGlass.isAvailable, isEnabled, let dropdownMenu, let menu else { return false }
        dropdownMenu.show(menu: menu, from: self, selectedItem: selectedItem) { [weak self] item in
            guard let self, self.selectedItem !== item else { return }
            self.select(item)
            self.sendAction(self.action, to: self.target)
        }
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        if glassBackground.isHidden {
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            NSColor(white: dark ? 0.25 : 0.87, alpha: 1).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let text = NSAttributedString(string: titleOfSelectedItem ?? "", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.85),
            .paragraphStyle: paragraph
        ])
        let inset = glassBackground.isHidden ? Self.classicTitleInset : 11
        let textHeight = ceil(text.size().height)
        text.draw(in: NSRect(x: bounds.minX + inset, y: bounds.midY - textHeight / 2,
                             width: max(0, bounds.width - inset - 22), height: textHeight))
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
final class PreferenceSwitch: NSView {
    private let classic = ClassicPreferenceSwitch()
    private let native = LiquidGlass.isAvailable ? NativePreferenceSwitch() : nil

    var state: NSControl.StateValue {
        if let native, !native.isHidden { return native.state }
        return classic.state
    }

    var isTrackingMouse: Bool { classic.isTrackingMouse || native?.isTrackingMouse == true }

    override var intrinsicContentSize: NSSize {
        guard let native else { return ClassicPreferenceSwitch.size }
        let nativeSize = native.intrinsicContentSize
        return NSSize(width: max(ClassicPreferenceSwitch.size.width, nativeSize.width),
                      height: max(ClassicPreferenceSwitch.size.height, nativeSize.height))
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(classic)
        guard let native else { return }
        native.controlSize = .small
        native.isHidden = true
        native.translatesAutoresizingMaskIntoConstraints = false
        addSubview(native)
        NSLayoutConstraint.activate([
            native.leadingAnchor.constraint(equalTo: leadingAnchor),
            native.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let size = ClassicPreferenceSwitch.size
        let x = userInterfaceLayoutDirection == .rightToLeft ? bounds.maxX - size.width : bounds.minX
        classic.frame = NSRect(x: x, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    func configure(label: String, target: AnyObject, action: Selector) {
        let controls: [NSControl?] = [classic, native]
        for control in controls.compactMap({ $0 }) {
            control.target = target
            control.action = action
            control.setAccessibilityLabel(label)
        }
    }

    func updateLiquidGlass(_ enabled: Bool) {
        guard let native, enabled != classic.isHidden else { return }
        let focused = window?.firstResponder === (enabled ? classic : native)
        classic.isHidden = enabled
        native.isHidden = !enabled
        if focused {
            window?.makeFirstResponder(enabled ? native : classic)
        }
    }

    func updateState(_ newState: NSControl.StateValue, animated: Bool) {
        let animate = animated && window?.isVisible == true
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        classic.updateState(newState, animated: animate && !classic.isHidden)
        guard let native else { return }
        let nativeState: NSControl.StateValue = newState == .off ? .off : .on
        guard native.state != nativeState else { return }
        if animate && !native.isHidden {
            native.animator().state = nativeState
        } else {
            native.state = nativeState
        }
    }
}

@MainActor
private final class NativePreferenceSwitch: NSSwitch {
    private(set) var isTrackingMouse = false

    override func mouseDown(with event: NSEvent) {
        isTrackingMouse = true
        defer { isTrackingMouse = false }
        super.mouseDown(with: event)
    }
}

@MainActor
private final class ClassicPreferenceSwitch: NSButton {
    static let size = NSSize(width: 44, height: 20)
    private static let thumbSize = NSSize(width: 26, height: 16)
    private static let thumbInset: CGFloat = 2
    private let trackLayer = CALayer()
    private let thumbLayer = CALayer()
    private var showsOn = false
    private(set) var isTrackingMouse = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setButtonType(.switch)
        title = ""
        isBordered = false
        wantsLayer = true
        thumbLayer.backgroundColor = NSColor.white.cgColor
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(thumbLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        isTrackingMouse = true
        defer { isTrackingMouse = false }
        super.mouseDown(with: event)
    }

    func updateState(_ newState: NSControl.StateValue, animated: Bool) {
        allowsMixedState = newState == .mixed
        state = newState
        showsOn = newState != .off
        updateLayers(animated: animated)
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
        guard !bounds.isEmpty else { return }
        let track = bounds
        let inset = Self.thumbInset + Self.thumbSize.width / 2
        let position = CGPoint(x: showsOn ? track.maxX - inset : track.minX + inset, y: track.midY)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = track
        trackLayer.cornerRadius = track.height / 2
        thumbLayer.bounds.size = Self.thumbSize
        thumbLayer.cornerRadius = Self.thumbSize.height / 2

        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color = (showsOn ? NSColor.controlAccentColor : NSColor.labelColor.withAlphaComponent(0.12)).cgColor
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
    var usesLiquidGlass = false { didSet { needsDisplay = true } }
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
        let tokenColor = usesLiquidGlass ? NSColor.labelColor.withAlphaComponent(0.1)
            : NSColor(named: "hotkey.token.fill") ?? .controlColor
        var x: CGFloat = 5
        for token in tokens {
            let width = keyWidth(token)
            let key = NSRect(x: x, y: bounds.midY - 12, width: width, height: 24)
            tokenColor.setFill()
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
