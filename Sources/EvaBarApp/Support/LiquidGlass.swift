import AppKit

@MainActor
enum LiquidGlass {
    static let preferenceKey = "liquidGlassEnabled"

    static var isAvailable: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    // The visible appearance follows the saved preference once the switch finishes moving.
    static var isEnabled = isAvailable && (UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true)
}

@MainActor
final class LiquidGlassBackground: NSView {
    private let radius: CGFloat
    private var effectView: NSView?

    init(cornerRadius: CGFloat) {
        radius = cornerRadius
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
        isHidden = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func wrap(_ control: NSControl) -> NSView {
        let container = NSView()
        for view in [self, control] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
        return container
    }

    func update(enabled: Bool) {
        guard #available(macOS 26, *), enabled else {
            isHidden = true
            return
        }
        if effectView == nil {
            let effect = NSGlassEffectView(frame: bounds)
            effect.cornerRadius = radius
            effect.autoresizingMask = [.width, .height]
            addSubview(effect)
            effectView = effect
        }
        isHidden = false
    }
}

extension NSButton {
    func useLiquidGlassBezel(_ enabled: Bool) {
        if #available(macOS 26, *) {
            prefersCompactControlSizeMetrics = enabled
            bezelStyle = enabled ? .glass : .automatic
            borderShape = enabled ? .capsule : .automatic
        }
        isBordered = enabled
    }
}
