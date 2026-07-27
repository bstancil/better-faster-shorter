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

// MARK: - Paste simulation

func postCmdV() {
    guard let src = CGEventSource(stateID: .combinedSessionState) else {
        log("failed to create event source")
        return
    }
    // Suppress the physically-held Cmd+Opt keys while the synthetic event
    // posts; otherwise they merge in and the app receives Cmd+Opt+V.
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
    down.flags = .maskCommand
    up.flags = .maskCommand
    down.post(tap: .cgAnnotatedSessionEventTap)
    up.post(tap: .cgAnnotatedSessionEventTap)
    log("posted synthetic cmd+v")
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

func handleHotKey() {
    let trusted = AXIsProcessTrusted()
    log("hotkey pressed (accessibility trusted: \(trusted))")
    if !trusted {
        // Don't prompt here — the launch-time prompt already covers it,
        // and re-prompting on every keypress is obnoxious.
        return
    }
    let pb = NSPasteboard.general
    guard let text = pb.string(forType: .string) else {
        postCmdV()
        return
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let cleaned = cleanURLString(trimmed), cleaned != trimmed else {
        // Not a URL, or nothing to strip: behave like a normal paste.
        postCmdV()
        return
    }

    let saved = snapshotPasteboard(pb)
    pb.clearContents()
    pb.setString(cleaned, forType: .string)
    let temporaryChangeCount = pb.changeCount
    postCmdV()
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
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_: Notification) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        log("launched (accessibility trusted: \(trusted))")
        registerHotKey()
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            handleHotKey()
            return noErr
        }, 1, &eventType, nil, nil)

        let hotKeyID = EventHotKeyID(signature: OSType(0x5550_4153), id: 1) // 'UPAS'
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        log("hotkey registration status: \(status) (0 = ok)")
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
