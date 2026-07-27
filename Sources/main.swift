import Cocoa
import Carbon.HIToolbox

// MARK: - URL cleaning

// Strip every query param EXCEPT these known-functional ones.
// (Plain Cmd+V always pastes the original, so over-stripping is cheap.)
let functionalParams: Set<String> = [
    "q",     // search queries
    "v",     // youtube video id
    "t",     // timestamps (youtube "start at")
    "list",  // youtube playlists
    "id",    // generic resource id
    "p",     // generic page/post id
    "page",  // pagination
]

/// Returns a cleaned URL string, or nil if the input isn't an http(s) URL.
func cleanURLString(_ s: String) -> String? {
    guard var comps = URLComponents(string: s),
          let scheme = comps.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          comps.host != nil
    else { return nil }

    if let items = comps.queryItems, !items.isEmpty {
        let kept = items.filter { functionalParams.contains($0.name.lowercased()) }
        comps.queryItems = kept.isEmpty ? nil : kept
    }
    return comps.url?.absoluteString
}

// MARK: - Logging
//
// Disabled by default. Flip to true and rerun ./install.sh to debug;
// logs go to ~/Library/Logs/BetterFasterShorter.log. Only status is ever logged
// (hotkey presses, permission state) — never clipboard contents.
let loggingEnabled = false

let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/BetterFasterShorter.log")

func log(_ message: String) {
    guard loggingEnabled else { return }
    let fmt = ISO8601DateFormatter()
    let line = "\(fmt.string(from: Date())) \(message)\n"
    if let data = line.data(using: .utf8) {
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: logURL)
        }
    }
}

// MARK: - Cmd+Shift+V
//
// Cmd+Shift+V is "paste without formatting" in most apps. When enabled, the
// app intercepts it, cleans a copied URL exactly like Cmd+Opt+V does, then
// re-sends Cmd+Shift+V so the paste itself still strips formatting. Flip to
// false and rerun ./install.sh to leave Cmd+Shift+V alone.
let interceptCmdShiftV = true

// MARK: - Paste simulation

func postPaste(_ flags: CGEventFlags) {
    guard let src = CGEventSource(stateID: .combinedSessionState) else {
        log("failed to create event source")
        return
    }
    // Suppress the physically-held hotkey modifiers while the synthetic event
    // posts; otherwise they merge in and the app receives e.g. Cmd+Opt+V.
    src.setLocalEventsFilterDuringSuppressionState(
        [.permitLocalMouseEvents, .permitSystemDefinedEvents],
        state: .eventSuppressionStateSuppressionInterval
    )
    src.setLocalEventsFilterDuringSuppressionState(
        [.permitLocalMouseEvents, .permitSystemDefinedEvents],
        state: .eventSuppressionStateRemoteMouseDrag
    )
    guard let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
          let up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
    else {
        log("failed to create key events")
        return
    }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cgAnnotatedSessionEventTap)
    up.post(tap: .cgAnnotatedSessionEventTap)
    log("posted synthetic paste (flags: \(flags.rawValue))")
}

func snapshotPasteboard(_ pb: NSPasteboard) -> [NSPasteboardItem] {
    (pb.pasteboardItems ?? []).map { item in
        let copy = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) {
                copy.setData(data, forType: type)
            }
        }
        return copy
    }
}

// MARK: - Hotkeys

let hotKeySignature = OSType(0x5550_4153) // 'UPAS'
let cleanPasteID: UInt32 = 1 // Cmd+Opt+V
let shiftPasteID: UInt32 = 2 // Cmd+Shift+V

var cleanPasteHotKeyRef: EventHotKeyRef?
var shiftPasteHotKeyRef: EventHotKeyRef?

func registerShiftPasteHotKey() {
    guard shiftPasteHotKeyRef == nil else { return }
    let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: shiftPasteID)
    let status = RegisterEventHotKey(
        UInt32(kVK_ANSI_V),
        UInt32(cmdKey | shiftKey),
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &shiftPasteHotKeyRef
    )
    log("cmd+shift+v registration status: \(status) (0 = ok)")
}

func unregisterShiftPasteHotKey() {
    guard let ref = shiftPasteHotKeyRef else { return }
    UnregisterEventHotKey(ref)
    shiftPasteHotKeyRef = nil
}

func handleHotKey(id: UInt32) {
    let trusted = AXIsProcessTrusted()
    log("hotkey \(id == shiftPasteID ? "cmd+shift+v" : "cmd+opt+v") pressed (accessibility trusted: \(trusted))")
    if !trusted {
        // Don't prompt here — the launch-time prompt already covers it,
        // and re-prompting on every keypress is obnoxious.
        return
    }

    // Cmd+Opt+V pastes as a plain Cmd+V. Cmd+Shift+V re-sends itself so the
    // target app still strips formatting; the hotkey is unregistered around
    // the synthetic keystroke so it can't re-trigger itself.
    let post: () -> Void
    if id == shiftPasteID {
        post = {
            unregisterShiftPasteHotKey()
            postPaste([.maskCommand, .maskShift])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                registerShiftPasteHotKey()
            }
        }
    } else {
        post = { postPaste(.maskCommand) }
    }

    let pb = NSPasteboard.general
    guard let text = pb.string(forType: .string) else {
        post()
        return
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let cleaned = cleanURLString(trimmed), cleaned != trimmed else {
        // Not a URL, or nothing to strip: behave like a normal paste.
        post()
        return
    }

    let saved = snapshotPasteboard(pb)
    pb.clearContents()
    pb.setString(cleaned, forType: .string)
    let temporaryChangeCount = pb.changeCount
    post()
    // Restore the original clipboard so plain Cmd+V still pastes the full URL.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        // Don't overwrite anything the user copied while the cleaned URL
        // was temporarily on the pasteboard.
        guard pb.changeCount == temporaryChangeCount else { return }
        pb.clearContents()
        pb.writeObjects(saved)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        log("launched (accessibility trusted: \(trusted))")
        registerHotKeys()
    }

    private func registerHotKeys() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            handleHotKey(id: hotKeyID.id)
            return noErr
        }, 1, &eventType, nil, nil)

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: cleanPasteID)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &cleanPasteHotKeyRef
        )
        log("cmd+opt+v registration status: \(status) (0 = ok)")
        if interceptCmdShiftV {
            registerShiftPasteHotKey()
        }
    }
}

// CLI mode for testing: `BetterFasterShorter --clean <url>` prints the cleaned URL and exits.
let args = CommandLine.arguments
if args.count >= 3, args[1] == "--clean" {
    print(cleanURLString(args[2]) ?? args[2])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
