import AppKit
import EvaBarCore
import Carbon.HIToolbox

@MainActor
final class CalculatorController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private enum Drawer { case functions, preferences }

    private weak var anchor: NSStatusBarButton?
    private let shortcuts: GlobalShortcut
    private var preferences: CalculatorPreferences
    private let defaults = UserDefaults.standard
    private let panel = CalculatorPanel()
    private let panelView = CalculatorPanelView()
    private var bar: CalculatorBarView { panelView.bar }
    private var aboutWindow: AboutWindow?
    private var reference: DrawerGrid?
    private var drawer: Drawer?
    private var resultText: String?
    private var copiedTimer: Timer?
    private var revealTask: Task<Void, Never>?
    private var outsideClickMonitor: Any?
    private var localMonitor: Any?
    private var isPinned = false
    private var isClosing = false
    private var isShowingMenu = false
    private var isRecordingShortcut = false
    var onLanguageChange: (() -> Void)?

    init(anchor: NSStatusBarButton, shortcuts: GlobalShortcut) {
        self.anchor = anchor
        self.shortcuts = shortcuts
        preferences = CalculatorPreferences(statusButton: anchor)
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
        if drawer == .preferences {
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
        configurePanelControls()
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
            if self.drawer == .preferences { self.resizePanel() }
        }
        preferences.onRecord = { [weak self] in self?.beginShortcutRecording() }
        preferences.onClear = { [weak self] in self?.clearShortcut() }
        preferences.onRestore = { [weak self] in self?.restoreShortcut() }
        preferences.onLanguageChange = { [weak self] in self?.applyLanguage() }
    }

    private func applyLanguage() {
        bar.updateLocalization()
        configurePanelControls()
        reference = nil
        aboutWindow?.updateLocalization()
        if let anchor {
            preferences = CalculatorPreferences(statusButton: anchor)
            connectPreferences()
        }
        onLanguageChange?()
        updateResult()
        if drawer == .preferences {
            isRecordingShortcut = false
            showPreferences()
            resizePanel()
            panel.recalculateKeyViewLoop()
        }
    }

    private func configure(_ button: NSButton, symbol: String, artwork: String?, artworkSize: CGFloat = 20,
                           label: String, action: Selector) {
        button.isBordered = false
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
                    if self.drawer != nil { self.panelView.scrollDrawerToTop() }
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
            panel.resize(to: CalculatorPanel.retractedFrame(for: panel.frame), animated: true)
        }
        panel.orderOut(nil)
        clearCopyFeedback()
        panel.ignoresMouseEvents = false
        isClosing = false
        setDrawer(nil)
    }

    private var statusButtonFrame: NSRect? {
        guard let anchor, let window = anchor.window else { return nil }
        return window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
    }

    private func installEventMonitors() {
        let mouseDown: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseDown) { [weak self] event in
            self?.dismissFromOutside(at: event.locationInWindow)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseDown.union(.keyDown)) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                guard self.panel.isKeyWindow, event.window == self.panel || event.window == nil else { return event }
                return self.handleKey(event)
            }
            if event.window != self.panel {
                let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
                self.dismissFromOutside(at: point)
            }
            return event
        }
    }

    private func dismissFromOutside(at point: NSPoint) {
        guard !isPinned, !isShowingMenu, !preferences.isShowingMenu,
              statusButtonFrame?.contains(point) != true else { return }
        hidePanel()
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard application?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        if revealTask != nil && !panel.isOnActiveSpace { return }
        dismissFromOutside(at: NSEvent.mouseLocation)
    }

    @objc private func activeSpaceChanged() {
        guard !isPinned, revealTask == nil, !panel.isOnActiveSpace else { return }
        hidePanel(animated: false)
    }

    @objc private func screenParametersChanged() {
        if panel.isVisible { resizePanel() }
    }

    private func panelFrame(on screen: NSScreen? = nil) -> NSRect? {
        guard let screen = screen ?? panel.screen ?? NSScreen.main else { return nil }
        let available = CalculatorPanel.availableFrame(on: screen)
        let barHeight = CalculatorPanel.barHeight
        let drawerHeight = drawer == nil ? 0 : panelView.drawerHeight(fittingWidth: available.width)
        let height = min(available.height, barHeight + drawerHeight)
        return NSRect(x: available.minX, y: available.maxY - height, width: available.width, height: height)
    }

    private func resizePanel(animated: Bool = false, on screen: NSScreen? = nil) {
        guard !isClosing, revealTask == nil, let frame = panelFrame(on: screen) else { return }
        if panel.frame != frame {
            // Keep the intermediate viewport sizes from making the scrollbar flash.
            panelView.setDrawerScrollerEnabled(false)
            panel.resize(to: frame, animated: animated)
        }
        panelView.setDrawerScrollerEnabled(drawer != nil)
    }

    private func setDrawer(_ newDrawer: Drawer?) {
        guard drawer != newDrawer else { return }
        isRecordingShortcut = false
        drawer = newDrawer

        switch newDrawer {
        case .functions:
            if reference == nil { reference = FunctionReference.makeGrid() }
            panelView.showDrawer(reference)
        case .preferences:
            showPreferences()
        case nil:
            panelView.showDrawer(nil)
        }

        if panel.isVisible {
            resizePanel(animated: true)
            if newDrawer != nil && revealTask == nil { panelView.scrollDrawerToTop() }
        }

        if panel.isVisible {
            panel.recalculateKeyViewLoop()
            if bar.expression.currentEditor() == nil { panel.makeFirstResponder(bar.expression) }
        }
    }

    private func showPreferences() {
        panelView.showDrawer(preferences.grid)
        preferences.refreshStartup()
        preferences.updateShortcut(shortcuts.shortcut, recording: false, message: nil)
    }

    private func updateResult() {
        clearCopyFeedback()
        let source = bar.expression.stringValue
        let format = preferences.format
        do {
            let text = if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                format.string(0)
            } else {
                format.string(try Expression.evaluate(source))
            }
            resultText = text
            bar.showResult(text)
        } catch {
            resultText = nil
            let messages = (error as? CalculationError)?.messages
                ?? (summary: L10n.text("Invalid expression"), detail: L10n.text("Check the expression and try again."))
            bar.showResult(messages.summary, errorDetail: messages.detail)
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let editor = bar.expression.currentEditor() as? NSTextView
        if !isRecordingShortcut && editor?.hasMarkedText() == true { return event }

        if event.keyCode == kVK_Escape {
            if isRecordingShortcut {
                endShortcutRecording()
            } else if drawer != nil {
                setDrawer(nil)
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
        setDrawer(.preferences)
    }

    @objc private func toggleFunctions() { setDrawer(drawer == .functions ? nil : .functions) }
    @objc private func togglePreferences() { setDrawer(drawer == .preferences ? nil : .preferences) }
    @objc private func collapseDrawer() { setDrawer(nil) }

    @objc private func showMenu() {
        let menu = NSMenu()
        addItem(L10n.text("Preferences…"), action: #selector(togglePreferences), to: menu)
        addItem(L10n.text("About"), action: #selector(showAbout), to: menu)
        addItem(L10n.text("Quit"), action: #selector(NSApplication.terminate(_:)), to: menu, target: NSApp)
        isShowingMenu = true
        defer { isShowingMenu = false }
        menu.popUp(positioning: nil, at: NSPoint(x: bar.moreButton.bounds.minX, y: bar.moreButton.bounds.minY), in: bar.moreButton)
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
        if drawer == .preferences { resizePanel() }
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
