import AppKit
import EvaBarCore
import ServiceManagement

@MainActor
final class CalculatorPreferences: NSObject, NSMenuDelegate {
    static let hideMenuBarIconKey = "hideMenuBarIcon"

    private static let icons: [(asset: String, symbol: String, title: String)] = [
        ("brand-mark", "function", "EvaBar (f)"), ("plus-minus", "plus.forwardslash.minus", "Plus or minus"),
        ("percent", "percent", "Percent"), ("number-sign", "number", "Number sign"),
        ("divide", "divide", "Division"), ("equal", "equal", "Equals"),
        ("not.equal", "notequal", "Not equal"), ("pi", "pi", "Pi constant"),
        ("sigma", "sum", "Summation"), ("sqrt", "x.squareroot", "Square root")
    ]

    private let defaults = UserDefaults.standard
    private let statusItem: NSStatusItem
    private let startup = PreferenceSwitch()
    private let startupMessage = NSButton(title: "", target: nil, action: nil)
    private var iconTiles: [PreferenceTile] = []
    private let hideIcon = PreferenceSwitch()
    private let precisionLabel = NSTextField(labelWithString: "")
    private let decrement = PreferenceTile()
    private let increment = PreferenceTile()
    private let language = SeparatorPicker()
    private let decimal = SeparatorPicker()
    private let grouping = SeparatorPicker()
    private let shortcutMessage = NSTextField(labelWithString: "")
    private let record = ShortcutEditorButton()
    private let clear = PreferenceTile()
    private(set) var format: ResultFormatting
    private(set) var isShowingMenu = false

    var onFormatChange: (() -> Void)?
    var onRecord: (() -> Void)?
    var onClear: (() -> Void)?
    var onRestore: (() -> Void)?
    var onLanguageChange: (() -> Void)?

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        let storedPlaces = defaults.object(forKey: "decimalPlaces") as? Int
        let places = storedPlaces.flatMap { ResultFormatting.decimalPlaces.contains($0) ? $0 : nil }
        let storedDecimal = defaults.string(forKey: "decimalSeparator").flatMap(NumberSeparator.init(rawValue:))
        let decimal: NumberSeparator = storedDecimal == .comma ? .comma : .period
        let defaultGrouping: NumberSeparator = decimal == .period ? .comma : .period
        let storedGrouping = defaults.string(forKey: "groupSeparator")
            .flatMap(NumberSeparator.init(rawValue:)) ?? defaultGrouping
        format = ResultFormatting(
            places: places ?? ResultFormatting.defaultPlaces, decimal: decimal,
            grouping: storedGrouping == decimal ? .none : storedGrouping
        )
        super.init()
        updateStatusIcon(at: selectedIconIndex)
        statusItem.isVisible = !defaults.bool(forKey: Self.hideMenuBarIconKey)
    }

    lazy var grid: DrawerGrid = {
        configureSwitch(startup, label: L10n.text("Launch at login"), action: #selector(changeStartup))
        startupMessage.target = self
        startupMessage.action = #selector(openLoginItems)
        startupMessage.isBordered = false
        startupMessage.contentTintColor = .controlAccentColor
        startupMessage.font = .systemFont(ofSize: 11)
        startupMessage.isHidden = true

        record.isBordered = false
        record.target = self
        record.action = #selector(recordShortcut)
        record.setAccessibilityLabel(L10n.text("Record global shortcut"))
        configureTile(clear, symbol: "xmark", label: L10n.text("Disable global shortcut"), action: #selector(clearShortcut), filled: false)
        let shortcutMenu = NSMenu()
        let reset = shortcutMenu.addItem(withTitle: L10n.text("Restore default shortcut"),
                                         action: #selector(restoreShortcut), keyEquivalent: "")
        reset.target = self
        shortcutMenu.delegate = self
        record.menu = shortcutMenu
        shortcutMessage.font = .systemFont(ofSize: 11)
        shortcutMessage.textColor = .secondaryLabelColor
        shortcutMessage.lineBreakMode = .byTruncatingTail
        shortcutMessage.isHidden = true

        configureTile(decrement, symbol: "chevron.left", label: L10n.text("Decrease decimal places"), action: #selector(changePrecision(_:)))
        configureTile(increment, symbol: "chevron.right", label: L10n.text("Increase decimal places"), action: #selector(changePrecision(_:)))
        decrement.tag = -1
        increment.tag = 1
        precisionLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        precisionLabel.alignment = .center
        precisionLabel.widthAnchor.constraint(equalToConstant: 37).isActive = true
        let resetPrecision = tile(symbol: "xmark", label: L10n.text("Restore default precision"), action: #selector(restorePrecision), filled: false)

        configurePopup(language, titles: [L10n.text("System Language")] + AppLanguage.allCases.map(\.displayName),
                       label: L10n.text("Language"), action: #selector(changeLanguage), width: 178)
        if let selected = L10n.selectedLanguage, let index = AppLanguage.allCases.firstIndex(of: selected) {
            language.selectItem(at: index + 1)
        }
        configurePopup(decimal, titles: [L10n.text("Period (.)"), L10n.text("Comma (,)")], label: L10n.text("Decimal separator"), action: #selector(changeDecimal))
        configurePopup(grouping, titles: [L10n.text("Comma (,)"), L10n.text("Period (.)"), L10n.text("None")], label: L10n.text("Grouping separator"), action: #selector(changeGrouping))
        refreshFormatControls()

        iconTiles = Self.icons.indices.map { index in
            let choice = Self.icons[index]
            let button = tile(symbol: choice.symbol, label: L10n.text(choice.title), action: #selector(changeIcon(_:)))
            button.tag = index
            button.image = imageForIcon(at: index, fitting: 16)
            button.contentTintColor = NSColor(named: "TextPrimary") ?? .labelColor
            button.selected = index == selectedIconIndex
            return button
        }
        let hideIconTitle = L10n.text("Hide menu bar icon")
        configureSwitch(hideIcon, label: hideIconTitle, action: #selector(changeIconVisibility))
        hideIcon.updateState(statusItem.isVisible ? .off : .on, animated: false)
        let hideIconLabel = NSTextField(labelWithString: hideIconTitle)
        hideIconLabel.font = .systemFont(ofSize: 13)
        let iconSection = section(L10n.text("Menu bar icon"), controls: [
            DrawerGrid.row(iconTiles, spacing: 6),
            DrawerGrid.row([hideIcon, hideIconLabel], spacing: 8)
        ])
        let shortcutRow = ControlBand(views: [record, clear])
        shortcutRow.orientation = .horizontal
        shortcutRow.alignment = .centerY
        shortcutRow.spacing = 2
        shortcutRow.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
        let shortcut = section(L10n.text("Global shortcut"), controls: [shortcutRow, shortcutMessage])
        shortcutMessage.widthAnchor.constraint(lessThanOrEqualTo: shortcut.widthAnchor).isActive = true
        let places = DrawerGrid.row([decrement, precisionLabel, increment, resetPrecision], spacing: 0)
        places.setCustomSpacing(6, after: increment)
        let separators = DrawerGrid.row([
            section(L10n.text("Decimal separator"), controls: [decimal]),
            section(L10n.text("Grouping separator"), controls: [grouping])
        ], spacing: 16)
        separators.alignment = .top
        let sections = [
            section(L10n.text("Launch at login"), controls: [switchContainer(), startupMessage]),
            section(L10n.text("Language"), controls: [language]),
            shortcut,
            iconSection,
            section(L10n.text("Decimal places"), controls: [places]),
            separators
        ]
        return DrawerGrid(
            sections: sections, columnCounts: [3, 2, 1], minimumColumnWidth: 328,
            horizontalInset: 24, verticalInset: 17, bottomInset: 17
        )
    }()

    private func switchContainer() -> NSView {
        let stack = DrawerGrid.row([startup], spacing: 0)
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 0, right: 0)
        return stack
    }

    private func section(_ title: String, controls: [NSView]) -> NSStackView {
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 13, weight: .regular)
        heading.textColor = NSColor.labelColor.withAlphaComponent(0.85)
        return DrawerGrid.column([heading] + controls, spacing: 10)
    }

    private var selectedIconIndex: Int {
        let storedIcon = defaults.string(forKey: "menuBarIcon")
        return Self.icons.firstIndex { $0.symbol == storedIcon } ?? 0
    }

    private func imageForIcon(at index: Int, fitting size: CGFloat? = nil) -> NSImage? {
        let choice = Self.icons[index]
        let label = L10n.text(choice.title)
        let image = AppArtwork.template(choice.asset, fitting: size)
            ?? NSImage(systemSymbolName: choice.symbol, accessibilityDescription: label)?
                .withSymbolConfiguration(.init(pointSize: size ?? 15, weight: .medium))
        image?.isTemplate = true
        image?.accessibilityDescription = label
        return image
    }

    private func updateStatusIcon(at index: Int) {
        guard let statusButton = statusItem.button else { return }
        let image = imageForIcon(at: index) ?? imageForIcon(at: 0)
        statusButton.image = image
        statusButton.imagePosition = image == nil ? .noImage : .imageOnly
        statusButton.title = image == nil ? "f" : ""
    }

    private func configureSwitch(_ control: PreferenceSwitch, label: String, action: Selector) {
        control.setButtonType(.switch)
        control.title = ""
        control.isBordered = false
        control.target = self
        control.action = action
        control.setAccessibilityLabel(label)
        control.widthAnchor.constraint(equalToConstant: 38).isActive = true
        control.heightAnchor.constraint(equalToConstant: 22).isActive = true
    }

    private func configureTile(_ button: PreferenceTile, symbol: String, label: String, action: Selector, filled: Bool = true) {
        button.isBordered = false
        button.filled = filled
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.widthAnchor.constraint(equalToConstant: 25).isActive = true
        button.heightAnchor.constraint(equalToConstant: 25).isActive = true
    }

    private func tile(symbol: String, label: String, action: Selector, filled: Bool = true) -> PreferenceTile {
        let button = PreferenceTile()
        configureTile(button, symbol: symbol, label: label, action: action, filled: filled)
        return button
    }

    private func configurePopup(_ popup: NSPopUpButton, titles: [String], label: String,
                                action: Selector, width: CGFloat = 130) {
        popup.addItems(withTitles: titles)
        popup.font = .systemFont(ofSize: 13)
        popup.bezelStyle = .regularSquare
        popup.target = self
        popup.action = action
        popup.menu?.delegate = self
        popup.autoenablesItems = false
        popup.setAccessibilityLabel(label)
        popup.widthAnchor.constraint(equalToConstant: width).isActive = true
        popup.heightAnchor.constraint(equalToConstant: 25).isActive = true
    }

    func menuWillOpen(_ menu: NSMenu) { isShowingMenu = true }
    func menuDidClose(_ menu: NSMenu) { isShowingMenu = false }

    @objc private func changeLanguage() {
        let index = language.indexOfSelectedItem
        guard index >= 0 else { return }
        let selection = index == 0 ? nil : AppLanguage.allCases[index - 1]
        guard selection != L10n.selectedLanguage else { return }
        L10n.select(selection)
        // Let the popup finish tracking before the controller replaces the drawer.
        DispatchQueue.main.async { [weak self] in self?.onLanguageChange?() }
    }

    func refreshStartup(error: String? = nil, animated: Bool = false) {
        let status = SMAppService.mainApp.status
        let state: NSControl.StateValue = status == .enabled ? .on : status == .requiresApproval ? .mixed : .off
        startup.updateState(state, animated: animated)
        startupMessage.title = error ?? L10n.text("Allow in System Settings")
        startupMessage.isHidden = error == nil && status != .requiresApproval
    }

    func updateShortcut(_ shortcut: Shortcut?, recording: Bool, message: String?) {
        record.title = recording ? L10n.text("Type shortcut…") : shortcut?.displayName ?? L10n.text("Set shortcut…")
        record.tokens = recording ? [] : shortcut?.displayTokens ?? []
        clear.isEnabled = shortcut != nil
        shortcutMessage.stringValue = message ?? ""
        shortcutMessage.isHidden = message == nil
    }

    private func refreshFormatControls() {
        precisionLabel.stringValue = String(format.places)
        decrement.isEnabled = format.places > ResultFormatting.decimalPlaces.lowerBound
        increment.isEnabled = format.places < ResultFormatting.decimalPlaces.upperBound
        decimal.selectItem(at: format.decimal == .period ? 0 : 1)
        grouping.item(at: 0)?.isEnabled = format.decimal != .comma
        grouping.item(at: 1)?.isEnabled = format.decimal != .period
        switch format.grouping {
        case .comma: grouping.selectItem(at: 0)
        case .period: grouping.selectItem(at: 1)
        case .none: grouping.selectItem(at: 2)
        }
    }

    @objc private func changeIcon(_ sender: NSButton) {
        let index = sender.tag
        defaults.set(Self.icons[index].symbol, forKey: "menuBarIcon")
        for tile in iconTiles { tile.selected = tile.tag == index }
        updateStatusIcon(at: index)
    }

    @objc private func changeIconVisibility() {
        let hidden = hideIcon.state == .on
        defaults.set(hidden, forKey: Self.hideMenuBarIconKey)
        statusItem.isVisible = !hidden
        hideIcon.updateState(hidden ? .on : .off, animated: true)
    }

    @objc private func changeStartup() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            } else {
                try service.register()
            }
            refreshStartup(animated: true)
        } catch {
            refreshStartup(error: L10n.text("Could not update login item"))
        }
        onFormatChange?()
    }

    @objc private func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func recordShortcut() { onRecord?() }
    @objc private func clearShortcut() { onClear?() }
    @objc private func restoreShortcut() { onRestore?() }
    @objc private func changePrecision(_ sender: NSButton) { setPrecision(format.places + sender.tag) }
    @objc private func restorePrecision() { setPrecision(ResultFormatting.defaultPlaces) }

    private func setPrecision(_ places: Int) {
        guard ResultFormatting.decimalPlaces.contains(places) else { return }
        format = ResultFormatting(places: places, decimal: format.decimal, grouping: format.grouping)
        defaults.set(places, forKey: "decimalPlaces")
        refreshFormatControls()
        onFormatChange?()
    }

    @objc private func changeDecimal() {
        format.decimal = decimal.indexOfSelectedItem == 0 ? .period : .comma
        if format.grouping == format.decimal { format.grouping = .none }
        storeSeparators()
    }

    @objc private func changeGrouping() {
        guard grouping.indexOfSelectedItem >= 0 else { return }
        format.grouping = [.comma, .period, .none][grouping.indexOfSelectedItem]
        storeSeparators()
    }

    private func storeSeparators() {
        defaults.set(format.decimal.rawValue, forKey: "decimalSeparator")
        defaults.set(format.grouping.rawValue, forKey: "groupSeparator")
        refreshFormatControls()
        onFormatChange?()
    }
}
