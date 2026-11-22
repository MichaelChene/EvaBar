import AppKit

@MainActor
final class AboutWindow: NSWindow, NSWindowDelegate {
    private var previousActivationPolicy: NSApplication.ActivationPolicy?
    private let versionLabel = NSTextField(labelWithString: "")
    private let authorLabel = NSTextField(labelWithString: "")
    private let copyrightLabel = NSTextField(wrappingLabelWithString: "")

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 253),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        collectionBehavior = .moveToActiveSpace
        isReleasedWhenClosed = false
        delegate = self
        let icon = NSImageView(image: AppArtwork.applicationIcon)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.frame = NSRect(x: 161, y: 122, width: 68, height: 68)
        contentView?.addSubview(icon)

        let labels: [(NSTextField, CGFloat, CGFloat, CGFloat, NSFont.Weight)] = [
            (NSTextField(labelWithString: "Eva|Bar"), 79, 24, 18, .semibold),
            (versionLabel, 53, 24, 12, .semibold),
            (authorLabel, 32, 24, 12, .medium),
            (copyrightLabel, 4, 29, 11, .medium)
        ]
        for (label, y, height, size, weight) in labels {
            label.font = .systemFont(ofSize: size, weight: weight)
            label.textColor = size == 18 ? .labelColor : .secondaryLabelColor
            label.alignment = .center
            label.frame = NSRect(x: 12, y: y, width: 366, height: height)
            contentView?.addSubview(label)
        }
        copyrightLabel.maximumNumberOfLines = 2
        updateLocalization()
    }

    required init?(coder: NSCoder) { nil }

    func updateLocalization() {
        title = L10n.text("About Eva|Bar")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        versionLabel.stringValue = L10n.format("Version %@", version)
        authorLabel.stringValue = L10n.text("Created by Michael Chene")
        copyrightLabel.stringValue = L10n.text("Copyright © 2026 Michael Chene. All rights reserved.")
    }

    func present() {
        let policy = NSApp.activationPolicy()
        if policy != .regular, NSApp.setActivationPolicy(.regular) {
            previousActivationPolicy = policy
        }
        NSApp.activate(ignoringOtherApps: true)
        if !isVisible { center() }
        makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let previousActivationPolicy else { return }
        self.previousActivationPolicy = nil
        NSApp.setActivationPolicy(previousActivationPolicy)
    }
}
