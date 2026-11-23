import AppKit

@MainActor
final class CalculatorPanel: NSPanel {
    static let barHeight: CGFloat = 60
    private static let horizontalMargin: CGFloat = 20
    private static let screenTopOffset: CGFloat = 43
    private static let retractedHeight: CGFloat = 1
    private static let retractionFadeHeight: CGFloat = 24
    private var isRetracting = false

    override var canBecomeKey: Bool { true }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: Self.barHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "Eva|Bar"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .none
        setPinned(false)
    }

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval { 0.25 }

    var allowsMotion: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static func retractedFrame(for frame: NSRect) -> NSRect {
        NSRect(x: frame.minX, y: frame.maxY - retractedHeight, width: frame.width, height: retractedHeight)
    }

    func retract() {
        isRetracting = true
        resize(to: Self.retractedFrame(for: frame), animated: true)
        alphaValue = 0
        isRetracting = false
    }

    func updateRetractionOpacity(visibleHeight: CGFloat) {
        guard isRetracting else { return }
        let visible = max(0, visibleHeight - Self.retractedHeight)
        let opacity = visible / (Self.retractionFadeHeight - Self.retractedHeight)
        // AppKit can lay out the content at its minimum size during the final resize.
        // Keep the window fading out even if that briefly increases the layout height.
        if opacity < alphaValue { alphaValue = opacity }
    }

    func setPinned(_ pinned: Bool) {
        collectionBehavior = [.fullScreenAuxiliary, pinned ? .canJoinAllSpaces : .moveToActiveSpace]
    }

    func resize(to targetFrame: NSRect, animated: Bool) {
        guard frame != targetFrame else { return }
        setFrame(targetFrame, display: isVisible, animate: isVisible && animated && allowsMotion)
        invalidateShadow()
    }

    static func availableFrame(on screen: NSScreen) -> NSRect {
        let display = screen.frame
        let visible = screen.visibleFrame
        let margin = min(horizontalMargin, display.width / 10)
        let top = min(display.maxY - screenTopOffset, visible.maxY)
        return NSRect(
            x: display.minX + margin,
            y: min(visible.minY, top - barHeight),
            width: display.width - 2 * margin,
            height: max(barHeight, top - visible.minY)
        )
    }
}
