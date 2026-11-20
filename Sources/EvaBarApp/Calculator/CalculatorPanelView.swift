import AppKit

@MainActor
final class CalculatorPanelView: NSView {
    private struct DrawerTransition {
        let previous: [DrawerGrid]
        var windowHeights: (start: CGFloat, end: CGFloat)?
    }

    let bar = CalculatorBarView()
    let collapseButton = NSButton()
    private let backdrop = NSVisualEffectView()
    private let backdropTint = NSView()
    private let drawerScroll = NSScrollView()
    private let drawerContent = DrawerContentView()
    private var drawerGrids: [DrawerGrid] = []
    private var drawerTransition: DrawerTransition?
    private var gridHeights: [DrawerGrid: CGFloat] = [:]
    private var drawerWidth: CGFloat = 0
    private let divider = NSBox()
    private let drawerDivider = NSBox()
    private var visibleDrawerGrids: [DrawerGrid] {
        guard let previous = drawerTransition?.previous, previous.count > drawerGrids.count else {
            return drawerGrids
        }
        return previous
    }

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
        for line in [divider, drawerDivider] {
            line.boxType = .custom
            line.borderWidth = 0
            line.fillColor = NSColor(white: 0.47, alpha: 0.35)
        }
        drawerScroll.autohidesScrollers = true
        drawerScroll.drawsBackground = false
        drawerScroll.documentView = drawerContent
        [backdrop, bar, drawerScroll, divider, collapseButton].forEach { addSubview($0) }
        showDrawers([])
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
        positionContent()
    }

    override func layout() {
        super.layout()
        positionContent()
    }

    private func positionContent() {
        let barHeight = bar.height(fittingWidth: bounds.width)
        bar.frame = NSRect(x: 0, y: 0, width: bounds.width, height: barHeight)
        positionDrawer(below: barHeight)
    }

    private func positionDrawer(below barHeight: CGFloat) {
        guard !drawerScroll.isHidden else { return }
        // The panel clips the drawer while it animates. Keep the scroll view large enough to tile its scroller.
        let drawerHeight = max(24, bounds.height - barHeight)
        drawerScroll.frame = NSRect(x: 0, y: barHeight, width: bounds.width, height: drawerHeight)
        positionDrawerGrids()
        divider.frame = NSRect(x: 0, y: barHeight - 1, width: bounds.width, height: 1)
        collapseButton.frame = NSRect(x: bounds.width - 37, y: max(barHeight, bounds.height - 24), width: 26, height: 22)
    }

    func showDrawers(_ grids: [DrawerGrid], animated: Bool = false) {
        setDrawerScrollerEnabled(false)
        drawerTransition = animated ? DrawerTransition(previous: drawerGrids) : nil
        drawerGrids = grids
        let visible = visibleDrawerGrids
        drawerContent.subviews = visible + [drawerDivider]
        divider.isHidden = visible.isEmpty
        drawerScroll.isHidden = visible.isEmpty
        collapseButton.isHidden = visible.isEmpty
        needsLayout = true
    }

    func prepareDrawerTransition(from start: CGFloat, to end: CGFloat) {
        guard start != end else { return }
        drawerTransition?.windowHeights = (start, end)
    }

    func finishDrawerTransition() {
        guard drawerTransition != nil else { return }
        showDrawers(drawerGrids)
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
        let scrollerWidth = drawerScroll.scrollerStyle == .legacy
            ? NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy) : 0
        drawerWidth = max(1, width - scrollerWidth)
        gridHeights = Dictionary(uniqueKeysWithValues: visibleDrawerGrids.map { grid in
            (grid, grid.layoutContent(width: drawerWidth))
        })
        positionDrawerGrids()
        return drawerGrids.reduce(CGFloat(max(0, drawerGrids.count - 1))) { height, grid in
            height + (gridHeights[grid] ?? 0)
        }
    }

    private func positionDrawerGrids() {
        let previous = drawerTransition?.previous ?? drawerGrids
        let progress = drawerTransition?.windowHeights.map {
            min(1, max(0, (bounds.height - $0.start) / ($0.end - $0.start)))
        } ?? 0
        let oldDivider: CGFloat = previous.count > 1 ? 1 : 0
        let newDivider: CGFloat = drawerGrids.count > 1 ? 1 : 0
        let dividerHeight = oldDivider + (newDivider - oldDivider) * progress
        var y: CGFloat = 0
        drawerDivider.isHidden = dividerHeight == 0
        for (index, grid) in visibleDrawerGrids.enumerated() {
            if index > 0 {
                drawerDivider.frame = NSRect(x: 0, y: y, width: drawerWidth, height: dividerHeight)
                y += dividerHeight
            }
            let oldScale: CGFloat = previous.contains(grid) ? 1 : 0
            let newScale: CGFloat = drawerGrids.contains(grid) ? 1 : 0
            let scale = oldScale + (newScale - oldScale) * progress
            let height = (gridHeights[grid] ?? 0) * scale
            grid.frame = NSRect(x: 0, y: y, width: drawerWidth, height: height)
            y += height
        }
        drawerContent.setFrameSize(NSSize(width: drawerWidth, height: y))
    }
}

private final class DrawerContentView: NSView {
    override var isFlipped: Bool { true }
}
