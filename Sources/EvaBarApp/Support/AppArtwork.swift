import AppKit

@MainActor
enum AppArtwork {
    static let applicationIcon: NSImage = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        .flatMap(NSImage.init(contentsOf:)) ?? NSApp.applicationIconImage

    static func template(_ name: String, fitting size: CGFloat? = nil) -> NSImage? {
        guard let original = NSImage(named: NSImage.Name(name)),
              let image = original.copy() as? NSImage,
              image.size.width > 0, image.size.height > 0 else { return nil }
        if let size {
            let scale = size / max(image.size.width, image.size.height)
            image.size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        }
        image.isTemplate = true
        return image
    }
}
