import AppKit

@MainActor
final class AboutWindow: NSWindow, NSWindowDelegate {
    private var previousActivationPolicy: NSApplication.ActivationPolicy?
    private let versionLabel = NSTextField(labelWithString: "")
    private let authorLabel = NSTextField(labelWithString: "")
    private let copyrightLabel = NSTextField(wrappingLabelWithString: "")

    init() {
        let width: CGFloat = 360
        let horizontalInset: CGFloat = 24
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 216),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        collectionBehavior = .moveToActiveSpace
        isReleasedWhenClosed = false
        delegate = self

        let icon = NSImageView(image: AppArtwork.applicationIcon)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalTo: icon.widthAnchor).isActive = true

        let name = NSTextField(labelWithString: "Eva|Bar")
        name.font = .systemFont(ofSize: 20, weight: .semibold)
        for label in [versionLabel, authorLabel, copyrightLabel] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
        }
        copyrightLabel.font = .systemFont(ofSize: 11)
        copyrightLabel.maximumNumberOfLines = 2
        let textWidth = width - 2 * horizontalInset
        copyrightLabel.preferredMaxLayoutWidth = textWidth
        copyrightLabel.widthAnchor.constraint(equalToConstant: textWidth).isActive = true

        let details = NSStackView(views: [icon, name, versionLabel, authorLabel, copyrightLabel])
        details.orientation = .vertical
        details.alignment = .centerX
        details.spacing = 4
        details.setCustomSpacing(10, after: icon)
        details.setCustomSpacing(12, after: versionLabel)
        details.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(details)
        contentView = content
        NSLayoutConstraint.activate([
            details.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            details.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])
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
