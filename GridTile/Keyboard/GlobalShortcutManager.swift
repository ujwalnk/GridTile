import Carbon.HIToolbox
import AppKit

/// Registers and dispatches system-wide keyboard shortcuts (§9) using Carbon's
/// `RegisterEventHotKey`.
///
/// This is a deliberate choice over `NSEvent.addGlobalMonitorForEvents`: Carbon
/// hotkeys work regardless of Accessibility/Input-Monitoring trust, fire even
/// when GridTile has no windows at all, and are the same mechanism used by
/// long-established native tiling utilities (Rectangle, Spectacle, etc.).
/// `NSEvent` global monitors, by contrast, require Input Monitoring permission
/// and only report *did* events, which is unnecessary risk for something as
/// simple as "did the user press ⌃⌥1".
final class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?
    private let signature: OSType = {
        // 'GRDT' as a four-char code.
        let bytes: [UInt8] = Array("GRDT".utf8)
        return OSType(bytes[0]) << 24 | OSType(bytes[1]) << 16 | OSType(bytes[2]) << 8 | OSType(bytes[3])
    }()

    private init() {
        installEventHandlerIfNeeded()
    }

    /// Registers `shortcut` to invoke `handler` whenever pressed, regardless of
    /// the frontmost application. Returns an opaque token; pass it to
    /// `unregister(_:)` to remove it later. Registration fails (returns `nil`)
    /// if the combination is already claimed by another app — callers should
    /// surface `GridTileError.shortcutConflict` in that case (§9).
    @discardableResult
    func register(shortcut: KeyboardShortcut, handler: @escaping () -> Void) -> UInt32? {
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            return nil
        }

        hotKeyRefs[id] = hotKeyRef
        handlers[id] = handler
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = hotKeyRefs[id] {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeValue(forKey: id)
        handlers.removeValue(forKey: id)
    }

    func unregisterAll() {
        for id in Array(hotKeyRefs.keys) {
            unregister(id)
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                guard status == noErr else { return status }

                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handlers[hotKeyID.id]?()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }
}
