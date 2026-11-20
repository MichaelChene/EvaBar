import AppKit

@MainActor
final class CalculatorPanelView: NSView {
    let bar = CalculatorBarView()
    let collapseButton = NSButton()
    private let backdrop = NSVisualEffectView()
    private let backdropTint = NSView()
    private let drawerScroll = NSScrollView()
    private let divider = NSBox()

    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true

        backdrop.material = .popover
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdropTint.wantsLayer = true
        backdropTint.autoresizingMask = [.width, .height]
        backdrop.addSubview(backdropTint)
        divider.boxType = .custom
        divider.borderWidth = 0
        divider.fillColor = NSColor(white: 0.47, alpha: 0.35)
        drawerScroll.autohidesScrollers = true
        drawerScroll.drawsBackground = false
        [backdrop, bar, drawerScroll, divider, collapseButton].forEach { addSubview($0) }
        showDrawer(nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func updateLayer() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        backdropTint.layer?.backgroundColor = dark
            ? NSColor(srgbRed: 25 / 255.0, green: 26 / 255.0, blue: 29 / 255.0, alpha: 0.42).cgColor
            : NSColor(white: 0.97, alpha: 0.15).cgColor
        layer?.borderColor = NSColor(white: dark ? 1 : 0, alpha: 0.13).cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 13
        layer?.masksToBounds = true
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        backdrop.frame = bounds
        let barHeight = CalculatorPanel.barHeight
        bar.frame = NSRect(x: 0, y: 0, width: bounds.width, height: barHeight)
        positionDrawer()
    }

    private func positionDrawer() {
        guard !drawerScroll.isHidden else { return }
        let barHeight = CalculatorPanel.barHeight
        // The panel clips the drawer while it animates. Keep the scroll view large enough to tile its scroller.
        let drawerHeight = max(24, bounds.height - barHeight)
        drawerScroll.frame = NSRect(x: 0, y: barHeight, width: bounds.width, height: drawerHeight)
        divider.frame = NSRect(x: 0, y: barHeight - 1, width: bounds.width, height: 1)
        collapseButton.frame = NSRect(x: bounds.width - 37, y: max(barHeight, bounds.height - 24), width: 26, height: 22)
    }

    func showDrawer(_ content: DrawerGrid?) {
        setDrawerScrollerEnabled(false)
        drawerScroll.documentView = content
        divider.isHidden = content == nil
        drawerScroll.isHidden = content == nil
        collapseButton.isHidden = content == nil
        positionDrawer()
    }

    func setDrawerScrollerEnabled(_ enabled: Bool) {
        let documentHeight = drawerScroll.documentView?.frame.height ?? 0
        let needsScroller = enabled && documentHeight > drawerScroll.contentSize.height
        if drawerScroll.hasVerticalScroller != needsScroller {
            drawerScroll.hasVerticalScroller = needsScroller
        }
    }

    func scrollDrawerToTop() {
        drawerScroll.contentView.scroll(to: .zero)
        drawerScroll.reflectScrolledClipView(drawerScroll.contentView)
    }

    func drawerHeight(fittingWidth width: CGFloat) -> CGFloat {
        guard let content = drawerScroll.documentView as? DrawerGrid else { return 0 }
        let scrollerWidth = drawerScroll.scrollerStyle == .legacy
            ? NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy) : 0
        return content.layoutContent(width: max(1, width - scrollerWidth))
    }
}
