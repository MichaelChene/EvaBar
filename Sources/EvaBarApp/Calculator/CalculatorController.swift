import AppKit
import EvaBarCore
import Carbon.HIToolbox

@MainActor
final class CalculatorController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private enum Drawer { case functions, preferences }

    private let statusItem: NSStatusItem
    private var anchor: NSStatusBarButton? { statusItem.isVisible ? statusItem.button : nil }
    private let shortcuts: GlobalShortcut
    private var preferences: CalculatorPreferences
    private let dropdownMenu: DropdownMenu
    private let defaults = UserDefaults.standard
    private let panel = CalculatorPanel()
    private let panelView = CalculatorPanelView()
    private var bar: CalculatorBarView { panelView.bar }
    private var aboutWindow: AboutWindow?
    private var reference: DrawerGrid?
    private var drawers: Set<Drawer> = []
    private var resultText: String?
    private var copiedTimer: Timer?
    private var revealTask: Task<Void, Never>?
    private var appearanceChange: Task<Void, Never>?
    private var outsideClickMonitor: Any?
    private var localMonitor: Any?
    private var isPinned = false
    private var isClosing = false
    private var isShowingMenu = false
    private var isRecordingShortcut = false
    var onLanguageChange: (() -> Void)?

    init(statusItem: NSStatusItem, shortcuts: GlobalShortcut) {
        self.statusItem = statusItem
        self.shortcuts = shortcuts
        let dropdown = DropdownMenu()
        dropdownMenu = dropdown
        preferences = CalculatorPreferences(statusItem: statusItem, dropdownMenu: dropdown)
        super.init()

        if !defaults.bool(forKey: "shortcutDisabled") {
            let savedShortcut = defaults.data(forKey: "shortcut").flatMap {
                try? JSONDecoder().decode(Shortcut.self, from: $0)
            }
            if !shortcuts.register(savedShortcut ?? .standard), savedShortcut != nil {
                _ = shortcuts.register(.standard)
            }
        }

        connectPreferences()
        configurePanel()
        updateResult()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeApplicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeSpaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
    }

    @objc func togglePanel() {
        guard NSApp.modalWindow == nil else { return }
        if revealTask != nil || (panel.isVisible && panel.isOnActiveSpace) {
            hidePanel()
        } else {
            presentPanel()
        }
    }

    func handleShortcut() {
        if isRecordingShortcut {
            endShortcutRecording()
        } else {
            togglePanel()
        }
    }

    func controlTextDidChange(_ notification: Notification) { updateResult() }

    func windowDidBecomeKey(_ notification: Notification) {
        if drawers.contains(.preferences) {
            preferences.refreshStartup()
            resizePanel()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.revealTask == nil, !self.panel.isKeyWindow else { return }
            self.dismissFromOutside(at: NSEvent.mouseLocation)
        }
    }

    private func configurePanel() {
        panel.delegate = self
        panel.contentView = panelView
        panel.initialFirstResponder = bar.expression
        bar.expression.delegate = self
        panelView.onDrawerScroll = { [weak self] in self?.dropdownMenu.dismiss() }
        configurePanelControls()
        panelView.updateLiquidGlass(LiquidGlass.isEnabled)
    }

    private func configurePanelControls() {
        configure(bar.moreButton, symbol: "ellipsis", artwork: "menu-icon", artworkSize: 18,
                  label: L10n.text("More actions"), action: #selector(showMenu))
        configure(bar.lockButton, symbol: "lock.open", artwork: "unlock-thin-icon",
                  label: L10n.text("Pin panel"), action: #selector(togglePinned))
        if isPinned { updateLockButton() }
        configure(bar.helpButton, symbol: "function", artwork: "brand-mark", artworkSize: 18,
                  label: L10n.text("Functions"), action: #selector(toggleFunctions))
        configure(bar.copyButton, symbol: "document.on.document", artwork: "clipboard-thin-icon",
                  label: L10n.text("Copy result"), action: #selector(copyResult))
        configure(panelView.collapseButton, symbol: "chevron.up", artwork: nil,
                  label: L10n.text("Collapse"), action: #selector(collapseDrawer))
        panelView.collapseButton.contentTintColor = .secondaryLabelColor
    }

    private func connectPreferences() {
        preferences.onFormatChange = { [weak self] in
            guard let self else { return }
            self.updateResult()
        }
        preferences.onRecord = { [weak self] in self?.beginShortcutRecording() }
        preferences.onClear = { [weak self] in self?.clearShortcut() }
        preferences.onRestore = { [weak self] in self?.restoreShortcut() }
        preferences.onLanguageChange = { [weak self] in self?.applyLanguage() }
        preferences.onLiquidGlassChange = { [weak self] enabled in self?.setLiquidGlass(enabled) }
        preferences.onOtherSwitchChange = { [weak self] in self?.deferLiquidGlassChange() }
    }

    private func applyLanguage() {
        bar.updateLocalization()
        configurePanelControls()
        reference = nil
        aboutWindow?.updateLocalization()
        preferences = CalculatorPreferences(statusItem: statusItem, dropdownMenu: dropdownMenu)
        connectPreferences()
        onLanguageChange?()
        isRecordingShortcut = false
        refreshDrawers()
        updateResult()
        if !drawers.isEmpty {
            panel.recalculateKeyViewLoop()
        }
    }

    private func configure(_ button: NSButton, symbol: String, artwork: String?, artworkSize: CGFloat = 20,
                           label: String, action: Selector) {
        button.contentTintColor = NSColor(named: "TextPrimary") ?? .labelColor
        button.refusesFirstResponder = true
        button.target = self
        button.action = action
        setSymbol(on: button, symbol, artwork: artwork, artworkSize: artworkSize, label: label)
    }

    private func setSymbol(on button: NSButton, _ symbol: String, artwork: String? = nil,
                           artworkSize: CGFloat = 20, label: String) {
        let image = artwork.flatMap { AppArtwork.template($0, fitting: artworkSize) }
            ?? NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
        image?.accessibilityDescription = label
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = label
        button.setAccessibilityLabel(label)
    }

    func presentPanel() {
        guard !isClosing, revealTask == nil else { return }
        if panel.isVisible && !panel.isOnActiveSpace { hidePanel(animated: false) }

        if !panel.isVisible {
            let screen = presentationScreen
            if let targetFrame = panelFrame(on: screen) {
                if panel.allowsMotion {
                    panel.resize(to: CalculatorPanel.retractedFrame(for: targetFrame), animated: false)
                    revealWhenVisible(on: screen)
                } else {
                    panel.resize(to: targetFrame, animated: false)
                }
            }
            panel.alphaValue = 1
            installEventMonitors()
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(bar.expression)
    }

    private func revealWhenVisible(on screen: NSScreen?) {
        // Ordering a window onto a new Space can finish after orderFrontRegardless returns.
        // Let AppKit display the retracted frame before starting the resize.
        revealTask = Task { @MainActor [weak self] in
            let clock = ContinuousClock()
            let deadline = clock.now + .milliseconds(500)
            var wasVisible = false
            while !Task.isCancelled, let self {
                let visible = self.panel.isVisible
                    && self.panel.isOnActiveSpace
                    && self.panel.occlusionState.contains(.visible)
                let ready = visible && wasVisible
                if ready || clock.now >= deadline {
                    self.revealTask = nil
                    self.resizePanel(animated: ready, on: screen)
                    if !self.drawers.isEmpty { self.panelView.scrollDrawerToTop() }
                    if self.panel.isOnActiveSpace && !self.panel.isKeyWindow {
                        self.panel.makeKey()
                        self.panel.makeFirstResponder(self.bar.expression)
                    }
                    return
                }
                wasVisible = visible
                do {
                    try await clock.sleep(for: .milliseconds(16))
                } catch {
                    return
                }
            }
        }
    }

    private var presentationScreen: NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? anchor?.window?.screen
    }

    private func hidePanel(animated: Bool = true) {
        guard !isClosing, panel.isVisible || revealTask != nil else { return }
        isClosing = true
        dropdownMenu.dismiss()
        let wasOpening = revealTask != nil
        revealTask?.cancel()
        revealTask = nil
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        outsideClickMonitor = nil
        localMonitor = nil

        panel.ignoresMouseEvents = true
        panelView.setDrawerScrollerEnabled(false)
        if animated && !wasOpening && panel.isOnActiveSpace && panel.allowsMotion {
            panel.retract()
        }
        panel.orderOut(nil)
        clearCopyFeedback()
        panel.ignoresMouseEvents = false
        isClosing = false
        setDrawers([])
    }

    private var statusButtonFrame: NSRect? {
        guard let anchor, let window = anchor.window else { return nil }
        return window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
    }

    private func installEventMonitors() {
        let mouseDown: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseDown) { [weak self] event in
            guard let self else { return }
            self.dropdownMenu.dismiss()
            self.dismissFromOutside(at: event.locationInWindow)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseDown.union(.keyDown)) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                guard self.panel.isKeyWindow, event.window == self.panel || event.window == nil else { return event }
                if self.dropdownMenu.isVisible {
                    if event.keyCode == kVK_Tab, event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                        self.dropdownMenu.dismiss()
                        return event
                    }
                    self.dropdownMenu.handleKeyDown(event)
                    return nil
                }
                return self.handleKey(event)
            }
            if self.dropdownMenu.isVisible {
                if event.window === self.dropdownMenu { return event }
                self.dropdownMenu.dismiss()
                if event.window === self.panel { return nil }
            }
            if self.appearanceChange != nil, event.type == .leftMouseDown, event.window === self.panel,
               self.preferences.containsSwitch(at: event.locationInWindow, in: self.panel) {
                self.deferLiquidGlassChange()
            }
            if event.window != self.panel {
                let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
                self.dismissFromOutside(at: point)
            }
            return event
        }
    }

    private func dismissFromOutside(at point: NSPoint) {
        guard !isPinned, !isShowingMenu, !preferences.isShowingMenu, !dropdownMenu.isVisible,
              statusButtonFrame?.contains(point) != true else { return }
        hidePanel()
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard application?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        if revealTask != nil && !panel.isOnActiveSpace { return }
        dropdownMenu.dismiss()
        dismissFromOutside(at: NSEvent.mouseLocation)
    }

    @objc private func activeSpaceChanged() {
        dropdownMenu.dismiss()
        guard !isPinned, revealTask == nil, !panel.isOnActiveSpace else { return }
        hidePanel(animated: false)
    }

    @objc private func screenParametersChanged() {
        dropdownMenu.dismiss()
        if panel.isVisible { resizePanel() }
    }

    private func panelFrame(on screen: NSScreen? = nil) -> NSRect? {
        guard let screen = screen ?? panel.screen ?? NSScreen.main else { return nil }
        let available = CalculatorPanel.availableFrame(on: screen)
        let barHeight = bar.height(fittingWidth: available.width)
        let drawerHeight = panelView.drawerHeight(fittingWidth: available.width)
        let height = min(available.height, barHeight + drawerHeight)
        return NSRect(x: available.minX, y: available.maxY - height, width: available.width, height: height)
    }

    private func resizePanel(animated: Bool = false, on screen: NSScreen? = nil) {
        guard !isClosing, revealTask == nil, let frame = panelFrame(on: screen) else { return }
        if panel.frame != frame {
            // Keep the intermediate viewport sizes from making the scrollbar flash.
            panelView.setDrawerScrollerEnabled(false)
            panelView.prepareDrawerTransition(from: panel.frame.height, to: frame.height)
            panel.resize(to: frame, animated: animated)
        }
        panelView.finishDrawerTransition()
        panelView.layoutSubtreeIfNeeded()
        panelView.setDrawerScrollerEnabled(!drawers.isEmpty)
    }

    private func setDrawers(_ selection: Set<Drawer>) {
        guard drawers != selection else { return }
        dropdownMenu.dismiss()
        isRecordingShortcut = false
        drawers = selection
        refreshDrawers(animated: panel.isVisible && revealTask == nil && panel.allowsMotion)

        if panel.isVisible {
            resizePanel(animated: true)
            if !drawers.isEmpty && revealTask == nil { panelView.scrollDrawerToTop() }
            panel.recalculateKeyViewLoop()
            if bar.expression.currentEditor() == nil { panel.makeFirstResponder(bar.expression) }
        }
    }

    private func refreshDrawers(animated: Bool = false) {
        var grids: [DrawerGrid] = []
        if drawers.contains(.preferences) {
            grids.append(preferences.grid)
            preferences.refreshStartup()
            preferences.updateShortcut(shortcuts.shortcut, recording: false, message: nil)
        }
        if drawers.contains(.functions) {
            let grid = reference ?? FunctionReference.makeGrid()
            reference = grid
            grids.append(grid)
        }
        panelView.showDrawers(grids, animated: animated)
    }

    private func updateResult() {
        clearCopyFeedback()
        let source = bar.expression.stringValue
        let format = preferences.format
        do {
            let text = try format.string(forExpression: source)
            resultText = text
            bar.showResult(text)
        } catch {
            resultText = nil
            let calculationError = error as? CalculationError
            let messages = calculationError?.messages
                ?? (summary: L10n.text("Invalid expression"), detail: L10n.text("Check the expression and try again."))
            bar.showResult(messages.summary, errorDetail: messages.detail,
                           preservingResult: calculationError?.isEditingError == true)
        }
        panelView.needsLayout = true
        if panel.isVisible { resizePanel(animated: true) }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let editor = bar.expression.currentEditor() as? NSTextView
        if !isRecordingShortcut && editor?.hasMarkedText() == true { return event }

        if event.keyCode == kVK_Escape {
            if isRecordingShortcut {
                endShortcutRecording()
            } else if !drawers.isEmpty {
                setDrawers([])
            } else {
                hidePanel()
            }
            return nil
        }

        if isRecordingShortcut {
            if !event.isARepeat { recordShortcut(event) }
            return nil
        }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if flags == [.command], event.charactersIgnoringModifiers?.lowercased() == "c",
           (editor?.selectedRange().length ?? 0) == 0 {
            copyResult()
            return nil
        }
        if flags.isEmpty && editor != nil && (event.keyCode == kVK_Return || event.keyCode == kVK_ANSI_KeypadEnter) {
            copyResult()
            return nil
        }
        return event
    }

    @objc private func copyResult() {
        guard let resultText else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(resultText, forType: .string) else { return }
        copiedTimer?.invalidate()
        bar.showCopyConfirmation(true)
        copiedTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.clearCopyFeedback() }
        }
        NSAccessibility.post(
            element: panel, notification: .announcementRequested,
            userInfo: [.announcement: L10n.text("Result copied"), .priority: NSAccessibilityPriorityLevel.medium.rawValue]
        )
    }

    private func clearCopyFeedback() {
        guard let copiedTimer else { return }
        copiedTimer.invalidate()
        self.copiedTimer = nil
        bar.showCopyConfirmation(false)
    }

    @objc private func togglePinned() {
        isPinned.toggle()
        panel.setPinned(isPinned)
        updateLockButton()
    }

    private func updateLockButton() {
        setSymbol(on: bar.lockButton, isPinned ? "lock.fill" : "lock.open",
                  artwork: isPinned ? "lock-thin-icon" : "unlock-thin-icon", label: isPinned ? L10n.text("Unpin panel") : L10n.text("Pin panel"))
    }

    @objc func openPreferences() {
        guard !isClosing else { return }
        presentPanel()
        setDrawers(drawers.union([.preferences]))
    }

    @objc private func toggleFunctions() { setDrawers(drawers.symmetricDifference([.functions])) }
    @objc private func togglePreferences() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible, !self.isClosing else { return }
            self.setDrawers(self.drawers.symmetricDifference([.preferences]))
        }
    }
    @objc private func collapseDrawer() { setDrawers([]) }

    @objc private func showMenu() {
        let menu = NSMenu()
        addItem(L10n.text("Preferences…"), action: #selector(togglePreferences), to: menu)
        addItem(L10n.text("About"), action: #selector(showAbout), to: menu)
        addItem(L10n.text("Quit"), action: #selector(NSApplication.terminate(_:)), to: menu, target: NSApp)
        if LiquidGlass.isAvailable {
            dropdownMenu.show(menu: menu, from: bar.moreButton, anchorRect: bar.moreMenuAnchorRect) { item in
                if let action = item.action {
                    NSApp.sendAction(action, to: item.target, from: item)
                }
            }
            return
        }
        isShowingMenu = true
        defer { isShowingMenu = false }
        menu.popUp(positioning: nil, at: NSPoint(x: bar.moreButton.bounds.minX, y: bar.moreButton.bounds.minY), in: bar.moreButton)
    }

    private func setLiquidGlass(_ enabled: Bool) {
        defaults.set(enabled, forKey: LiquidGlass.preferenceKey)
        scheduleLiquidGlassChange(enabled)
    }

    private func deferLiquidGlassChange() {
        guard appearanceChange != nil else { return }
        scheduleLiquidGlassChange(defaults.bool(forKey: LiquidGlass.preferenceKey))
    }

    private func scheduleLiquidGlassChange(_ enabled: Bool) {
        let wasEnabled = LiquidGlass.isEnabled
        appearanceChange?.cancel()
        appearanceChange = nil
        guard enabled != wasEnabled else { return }
        guard panel.isVisible, panel.allowsMotion else {
            applyLiquidGlass(enabled)
            return
        }
        // Keep the current control visible through its classic or AppKit animation.
        let delay: Duration = wasEnabled ? .milliseconds(280) : .milliseconds(220)
        appearanceChange = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            if self.preferences.isTrackingSwitch ||
                (self.panel.isKeyWindow && NSEvent.pressedMouseButtons & 1 != 0) {
                self.deferLiquidGlassChange()
                return
            }
            self.appearanceChange = nil
            self.applyLiquidGlass(enabled)
        }
    }

    private func applyLiquidGlass(_ enabled: Bool) {
        LiquidGlass.isEnabled = enabled
        panelView.updateLiquidGlass(enabled)
        preferences.updateLiquidGlass(enabled)
        if dropdownMenu.isVisible { dropdownMenu.updateLiquidGlass(enabled) }
        resizePanel()
        panel.recalculateKeyViewLoop()
        panel.invalidateShadow()
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu, target: AnyObject? = nil) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = target ?? self
    }

    @objc private func showAbout() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.isPinned { self.hidePanel() }
            let window = self.aboutWindow ?? AboutWindow()
            self.aboutWindow = window
            window.present()
        }
    }

    private func updateShortcutControls(message: String? = nil) {
        preferences.updateShortcut(shortcuts.shortcut, recording: isRecordingShortcut, message: message)
        if drawers.contains(.preferences) { resizePanel() }
    }

    private func beginShortcutRecording() {
        isRecordingShortcut = true
        updateShortcutControls(message: L10n.text("Press a shortcut. Esc to cancel."))
        panel.makeFirstResponder(bar.expression)
    }

    private func endShortcutRecording() {
        isRecordingShortcut = false
        updateShortcutControls()
    }

    private func recordShortcut(_ event: NSEvent) {
        guard let candidate = Shortcut(event: event) else {
            updateShortcutControls(message: L10n.text("Include Control, Option, or Command."))
            return
        }
        guard shortcuts.register(candidate) else {
            updateShortcutControls(message: L10n.text("Shortcut unavailable. Try another."))
            return
        }
        if let data = try? JSONEncoder().encode(candidate) {
            defaults.set(data, forKey: "shortcut")
        }
        defaults.removeObject(forKey: "shortcutDisabled")
        endShortcutRecording()
    }

    private func clearShortcut() {
        shortcuts.stop()
        defaults.set(true, forKey: "shortcutDisabled")
        endShortcutRecording()
    }

    private func restoreShortcut() {
        guard shortcuts.register(.standard) else {
            updateShortcutControls(message: L10n.text("Default shortcut is unavailable."))
            return
        }
        defaults.removeObject(forKey: "shortcut")
        defaults.removeObject(forKey: "shortcutDisabled")
        endShortcutRecording()
    }
}
