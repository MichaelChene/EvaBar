import AppKit

@MainActor
enum FirstLaunchSetup {
    private static let completionKey = "didShowFirstLaunchSetup"

    static func shouldShow(defaults: UserDefaults, bundleIdentifier: String) -> Bool {
        guard !defaults.bool(forKey: completionKey) else { return false }
        let preferences = defaults.persistentDomain(forName: bundleIdentifier) ?? [:]
        let existingSettings = [
            "menuBarIcon", CalculatorPreferences.hideMenuBarIconKey, "shortcut", "shortcutDisabled",
            "decimalPlaces", "decimalSeparator", "groupSeparator"
        ]
        return !existingSettings.contains { preferences[$0] != nil }
            && !preferences.keys.contains { $0.hasPrefix("NSStatusItem ") }
    }

    static func show(defaults: UserDefaults, shortcut: Shortcut?, calculator: CalculatorController) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = AppArtwork.applicationIcon
        alert.messageText = L10n.text("Welcome to Eva|Bar")
        if let shortcut {
            alert.informativeText = L10n.format(
                "Open Eva|Bar from the menu bar or press %@. Change the shortcut and launch at login in Preferences.",
                shortcut.displayName
            )
        } else {
            alert.informativeText = L10n.text(
                "Open Eva|Bar from the menu bar. You can set a shortcut and enable launch at login in Preferences."
            )
        }
        alert.addButton(withTitle: L10n.text("Start Using Eva|Bar"))
        alert.addButton(withTitle: L10n.text("Open Preferences…"))
        defaults.set(true, forKey: completionKey)

        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        switch alert.runModal() {
        case .alertFirstButtonReturn: calculator.presentPanel()
        case .alertSecondButtonReturn: calculator.openPreferences()
        default: break
        }
    }
}
