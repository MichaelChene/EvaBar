import AppKit
import Carbon.HIToolbox

struct Shortcut: Codable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyName: String

    static let standard = Shortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey | shiftKey),
        keyName: "Space"
    )

    func matches(_ other: Shortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }

    @MainActor var displayTokens: [String] {
        var tokens: [String] = []
        if modifiers & UInt32(controlKey) != 0 { tokens.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { tokens.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { tokens.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { tokens.append("⌘") }
        return tokens + [keyCode == kVK_Space ? L10n.text("Space") : keyName]
    }

    @MainActor var displayName: String {
        displayTokens.joined()
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags
        guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }

        let keyNames: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
            kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
            kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
            kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14",
            kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
            kVK_F19: "F19", kVK_F20: "F20"
        ]
        let characters = event.characters(byApplyingModifiers: []) ?? ""
        let name = keyNames[Int(event.keyCode)] ?? characters.uppercased()
        guard !name.isEmpty, name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              !name.unicodeScalars.contains(where: { (0xF700...0xF8FF).contains($0.value) }) else { return nil }

        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyName: name)
    }

    private init(keyCode: UInt32, modifiers: UInt32, keyName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyName = keyName
    }
}

@MainActor
final class GlobalShortcut {
    private static let signature: OSType = 0x45766142 // EvaB
    private var handler: EventHandlerRef?
    private var registration: EventHotKeyRef?
    private var registrationID: UInt32 = 0
    private(set) var shortcut: Shortcut?
    var onPress: (() -> Void)?

    func register(_ candidate: Shortcut) -> Bool {
        if let shortcut, shortcut.matches(candidate) { return true }

        let target = GetApplicationEventTarget()
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(target, { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
                )
                guard status == noErr else { return status }
                return MainActor.assumeIsolated {
                    let owner = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
                    guard identifier.signature == GlobalShortcut.signature,
                          identifier.id == owner.registrationID else { return OSStatus(eventNotHandledErr) }
                    owner.onPress?()
                    return noErr
                }
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard status == noErr else { return false }
        }

        let nextID = registrationID == 1 ? UInt32(2) : UInt32(1)
        let identifier = EventHotKeyID(signature: Self.signature, id: nextID)
        var newRegistration: EventHotKeyRef?
        let status = RegisterEventHotKey(candidate.keyCode, candidate.modifiers, identifier, target, 0, &newRegistration)
        guard status == noErr, let newRegistration else { return false }
        if let registration { UnregisterEventHotKey(registration) }
        registration = newRegistration
        registrationID = nextID
        shortcut = candidate
        return true
    }

    func stop() {
        if let registration { UnregisterEventHotKey(registration) }
        if let handler { RemoveEventHandler(handler) }
        registration = nil
        handler = nil
        shortcut = nil
    }
}
