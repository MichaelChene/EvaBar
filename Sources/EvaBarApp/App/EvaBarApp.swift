import AppKit

@main
enum EvaBar {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let shortcuts = GlobalShortcut()
    private var statusItem: NSStatusItem?
    private var calculator: CalculatorController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "local.evabar.app"
        let showSetup = FirstLaunchSetup.shouldShow(defaults: defaults, bundleIdentifier: bundleIdentifier)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "EvaBar"
        guard let button = item.button else { return }
        button.setAccessibilityLabel("Eva|Bar")

        let calculator = CalculatorController(statusItem: item, shortcuts: shortcuts)
        button.toolTip = "Eva|Bar"
        button.target = calculator
        button.action = #selector(CalculatorController.togglePanel)
        shortcuts.onPress = { [weak calculator] in
            if NSApp.modalWindow == nil { calculator?.handleShortcut() }
        }

        installMainMenu(for: calculator)
        calculator.onLanguageChange = { [weak self, weak calculator] in
            guard let calculator else { return }
            self?.installMainMenu(for: calculator)
        }
        self.calculator = calculator
        statusItem = item
        if showSetup {
            DispatchQueue.main.async { [weak self, weak calculator] in
                guard let self, let calculator else { return }
                FirstLaunchSetup.show(defaults: defaults, shortcut: self.shortcuts.shortcut, calculator: calculator)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if NSApp.modalWindow == nil { calculator?.presentPanel() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcuts.stop()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    private func installMainMenu(for calculator: CalculatorController) {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Eva|Bar")
        let preferences = appMenu.addItem(
            withTitle: L10n.text("Preferences…"), action: #selector(CalculatorController.openPreferences), keyEquivalent: ","
        )
        preferences.target = calculator
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.text("Quit Eva|Bar"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: L10n.text("Edit"))
        edit.addItem(withTitle: L10n.text("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: L10n.text("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: L10n.text("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L10n.text("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L10n.text("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L10n.text("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
