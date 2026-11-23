import AppKit

@MainActor
final class DropdownMenu: NSPanel, NSTableViewDataSource, NSTableViewDelegate {
    private static let cornerRadius: CGFloat = 12
    private let rowHeight: CGFloat = 24
    private let inset: CGFloat = 5
    private let choiceTextInset: CGFloat = 25
    private let font = NSFont.systemFont(ofSize: 13)
    private let frostedBackdrop = NSVisualEffectView()
    private let glassBackdrop = LiquidGlassBackground(cornerRadius: cornerRadius)
    private let scroll = NSScrollView()
    private let table = DropdownTable()
    private var items: [NSMenuItem] = []
    private weak var anchor: NSView?
    private var anchorAccessibilityChildren: [Any]?
    private weak var currentItem: NSMenuItem?
    private var onSelection: ((NSMenuItem) -> Void)?

    override var canBecomeKey: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        acceptsMouseMovedEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        frostedBackdrop.material = .menu
        frostedBackdrop.blendingMode = .behindWindow
        frostedBackdrop.state = .active
        frostedBackdrop.wantsLayer = true
        frostedBackdrop.layer?.cornerRadius = Self.cornerRadius
        frostedBackdrop.layer?.masksToBounds = true
        let surface = NSView()
        surface.wantsLayer = true
        surface.layer?.cornerRadius = Self.cornerRadius
        surface.layer?.masksToBounds = true
        surface.layer?.borderWidth = 1
        surface.layer?.borderColor = NSColor.black.withAlphaComponent(0.28).cgColor
        [frostedBackdrop, glassBackdrop, scroll].forEach { surface.addSubview($0) }
        contentView = surface

        scroll.drawsBackground = false
        scroll.autohidesScrollers = true
        scroll.documentView = table

        table.headerView = nil
        table.style = .plain
        table.backgroundColor = .clear
        table.focusRingType = .none
        table.rowHeight = rowHeight
        table.intercellSpacing = .zero
        table.allowsTypeSelect = true
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("choice")))
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.action = #selector(chooseClickedRow)
        table.onConfirm = { [weak self] in
            guard let self else { return }
            self.chooseRow(self.table.selectedRow)
        }
        table.onCancel = { [weak self] in self?.dismiss() }
    }

    func show(menu: NSMenu, from anchor: NSView, anchorRect: NSRect? = nil, selectedItem: NSMenuItem? = nil,
              onSelection: @escaping (NSMenuItem) -> Void) {
        guard let parent = anchor.window, let screen = parent.screen ?? NSScreen.main else { return }
        dismiss()
        menu.update()
        items = menu.items.filter { !$0.isHidden }
        guard !items.isEmpty else { return }
        self.anchor = anchor
        currentItem = selectedItem
        self.onSelection = onSelection
        appearanceSource = anchor
        updateLiquidGlass(LiquidGlass.isEnabled)
        level = parent.level
        title = anchor.accessibilityLabel() ?? menu.title
        table.setAccessibilityLabel(title)

        let anchorFrame = parent.convertToScreen(anchor.convert(anchorRect ?? anchor.bounds, to: nil))
        let visible = screen.visibleFrame.insetBy(dx: inset, dy: inset)
        let textWidth = items.map { ($0.title as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let width = min(visible.width, max(anchorFrame.width, ceil(textWidth) + 44))
        let desiredHeight = CGFloat(items.count) * rowHeight + 2 * inset
        let height = min(visible.height, desiredHeight)
        let size = NSSize(width: width, height: height)
        setContentSize(size)

        let bounds = NSRect(origin: .zero, size: size)
        frostedBackdrop.frame = bounds
        glassBackdrop.frame = bounds
        scroll.frame = bounds.insetBy(dx: inset, dy: inset)
        scroll.hasVerticalScroller = height < desiredHeight
        scroll.tile()
        table.tableColumns[0].width = scroll.contentSize.width
        table.reloadData()
        table.scroll(.zero)

        let below = anchorFrame.minY - height
        var origin = NSPoint(x: anchorFrame.minX, y: below >= visible.minY ? below : anchorFrame.maxY)
        if let row = items.firstIndex(where: { $0 === selectedItem && $0.isEnabled }) {
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            table.scrollRowToVisible(row)
            let rowInWindow = table.convert(table.rect(ofRow: row), to: nil)
            origin.x -= anchorFrame.height / 2
            origin.y = anchorFrame.maxY - rowInWindow.maxY
        } else {
            table.deselectAll(nil)
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - height)
        setFrameOrigin(origin)
        parent.addChildWindow(self, ordered: .above)
        orderFront(nil)
        anchorAccessibilityChildren = anchor.accessibilityChildren()
        table.setAccessibilityParent(anchor)
        anchor.setAccessibilityChildren([table])
        NSAccessibility.post(element: anchor, notification: .layoutChanged)
    }

    func updateLiquidGlass(_ enabled: Bool) {
        frostedBackdrop.isHidden = enabled
        glassBackdrop.update(enabled: enabled)
    }

    func dismiss() {
        guard let parent = parent else { return }
        parent.removeChildWindow(self)
        orderOut(nil)
        if let anchor {
            anchor.setAccessibilityChildren(anchorAccessibilityChildren)
            NSAccessibility.post(element: anchor, notification: .layoutChanged)
        }
        table.setAccessibilityParent(nil)
        anchorAccessibilityChildren = nil
        anchor = nil
        currentItem = nil
        onSelection = nil
        items.removeAll()
        table.reloadData()
    }

    func handleKeyDown(_ event: NSEvent) {
        table.keyDown(with: event)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { items[row].isEnabled }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let view = DropdownRow()
        view.setAccessibilityEnabled(items[row].isEnabled)
        return view
    }

    func tableView(_ tableView: NSTableView, typeSelectStringFor tableColumn: NSTableColumn?, row: Int) -> String? {
        items[row].isEnabled ? items[row].title : nil
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: item.title)
        label.font = font
        label.lineBreakMode = .byTruncatingTail
        label.isEnabled = item.isEnabled
        label.textColor = item.isEnabled ? .labelColor : .disabledControlTextColor
        label.setAccessibilityEnabled(item.isEnabled)
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.textField = label
        cell.addSubview(label)
        let textInset = currentItem == nil ? inset : choiceTextInset
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: textInset),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        if item === currentItem, let image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil) {
            let check = NSImageView(image: image)
            check.symbolConfiguration = .init(pointSize: 11, weight: .semibold)
            check.translatesAutoresizingMaskIntoConstraints = false
            cell.imageView = check
            cell.addSubview(check)
            NSLayoutConstraint.activate([
                check.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
                check.widthAnchor.constraint(equalToConstant: 16),
                check.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        return cell
    }

    @objc private func chooseClickedRow() { chooseRow(table.clickedRow) }

    private func chooseRow(_ row: Int) {
        guard items.indices.contains(row), items[row].isEnabled else { return }
        let item = items[row]
        let action = onSelection
        dismiss()
        action?(item)
    }
}

@MainActor
private final class DropdownRow: NSTableRowView {
    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        isSelected ? .emphasized : super.interiorBackgroundStyle
    }

    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.selectedContentBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 1), xRadius: 5, yRadius: 5).fill()
    }
}

@MainActor
private final class DropdownTable: NSTableView {
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    private var hoverTracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let tracking = NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                      owner: self)
        addTrackingArea(tracking)
        hoverTracking = tracking
    }

    override func mouseMoved(with event: NSEvent) {
        let hoveredRow = row(at: convert(event.locationInWindow, from: nil))
        guard hoveredRow >= 0 else { return }
        if delegate?.tableView?(self, shouldSelectRow: hoveredRow) == false {
            deselectAll(nil)
        } else if hoveredRow != selectedRow {
            selectRowIndexes(IndexSet(integer: hoveredRow), byExtendingSelection: false)
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers {
        case "\u{1b}": onCancel?()
        case "\r", "\u{3}", " ": onConfirm?()
        default: super.keyDown(with: event)
        }
    }
}
