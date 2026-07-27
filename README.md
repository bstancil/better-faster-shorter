# Better, Faster, Shorter

A third paste shortcut for your Mac: **⌘⌥V pastes URLs without the tracking junk.**

You know the drill. Someone shares a link, you copy it, and what's on your
clipboard is this:

```
https://www.nytimes.com/2026/07/25/us/politics/some-article.html?campaign_id=60&emc=edit_na_20260725&instance_id=179334&nl=breaking-news&regi_id=52297349&segment_id=223691&user_id=c9acd82e34c2d4495e28bd852647882b
```

macOS already gives you ⌘V (paste) and ⌘⇧V (paste without formatting).
**Better, Faster, Shorter** adds ⌘⌥V: the same paste, minus the part of
the URL that works for the marketing department. The example above pastes as:

```
https://www.nytimes.com/2026/07/25/us/politics/some-article.html
```

Your original clipboard contents are restored after pasting, so plain ⌘V
still pastes the full URL. If ⌘⌥V ever strips something a link needed, just
paste it again the normal way.

## What it strips (and keeps)

Rather than playing whack-a-mole with every tracker (`utm_*`, `fbclid`,
`campaign_id`, and the thousand others), it strips **all** query
parameters except a short allowlist of functional ones:

| Kept  | Why                          |
|-------|------------------------------|
| `q`   | search queries               |
| `v`   | YouTube video ids            |
| `t`   | timestamps ("start at 0:42") |
| `list`| YouTube playlists            |
| `id`, `p`, `page` | generic resource ids and pagination |

Fragments are preserved, including `#:~:text=` link-to-highlight fragments.
If the clipboard isn't a URL, ⌘⌥V acts like a normal paste.

Some examples:

```
https://youtube.com/watch?v=dQw4w9WgXcQ&si=AbC123&t=42  →  https://youtube.com/watch?v=dQw4w9WgXcQ&t=42
https://google.com/search?q=hello&sca_esv=…&ved=…       →  https://google.com/search?q=hello
https://example.com/post?utm_source=newsletter#comments →  https://example.com/post#comments
```

To keep additional parameters, add them to `functionalParams` in
[Sources/main.swift](Sources/main.swift) and rerun `./install.sh`.

## Install

Requires macOS 13+ and Xcode command line tools (`xcode-select --install`).

```bash
git clone https://github.com/bstancil/better-faster-shorter.git
cd better-faster-shorter
./install.sh
```

This compiles the app (a single Swift file, no dependencies), installs it to
`~/Applications/Better, Faster, Shorter.app`, and registers a launch agent so it starts at
login. It runs invisibly — no menu bar icon, no dock icon.

**One manual step:** macOS will prompt for Accessibility access (the app
needs it to simulate the paste keystroke). Click "Open System Settings" and
toggle Better, Faster, Shorter on. Without this, ⌘⌥V does nothing.

## Uninstall

```bash
launchctl bootout gui/$UID/com.benn.better-faster-shorter
rm ~/Library/LaunchAgents/com.benn.better-faster-shorter.plist
rm -rf ~/Applications/"Better, Faster, Shorter.app"
```

## How it works

- Registers ⌘⌥V as a global hotkey (Carbon `RegisterEventHotKey`).
- On press, if the clipboard is an http(s) URL: saves the clipboard, writes
  the cleaned URL, posts a synthetic ⌘V keystroke, then restores the original
  clipboard ~0.6 seconds later unless you've copied something else.
- Clipboard contents never leave your machine or get written to disk. There's
  no network access, and logging is off by default (a status-only debug log can
  be enabled in the source; see Troubleshooting).

You can test the cleaner without pasting:

```bash
~/Applications/"Better, Faster, Shorter.app"/Contents/MacOS/BetterFasterShorter --clean "https://example.com/page?utm_source=x&id=42"
```

## Caveats

- **⌘⌥V is Finder's "Move item here" shortcut.** This app overrides it
  system-wide. If you use that, change the combo in `registerHotKey()` in
  [Sources/main.swift](Sources/main.swift) (e.g. add `shiftKey`).
- **Rebuilds may reset the Accessibility grant.** `install.sh` signs with the
  first code-signing identity in your keychain, which keeps the permission
  stable across rebuilds. With no identity available it falls back to ad-hoc
  signing, and macOS ties the grant to the exact binary — after a rebuild,
  toggle the app off and on again in System Settings → Privacy & Security →
  Accessibility.
- Apps with non-standard paste handling (some terminals, VMs) may ignore the
  synthetic keystroke.

## Troubleshooting

Set `loggingEnabled = true` in [Sources/main.swift](Sources/main.swift) and
rerun `./install.sh`. Each ⌘⌥V press then logs to `~/Library/Logs/BetterFasterShorter.log`:
whether the app has Accessibility access and whether the paste keystroke was
posted (status only — never clipboard contents). If pressing the hotkey logs
nothing, the app isn't running: `launchctl kickstart -k
gui/$UID/com.benn.better-faster-shorter`. If permission toggles won't stick, clear the
state and re-grant:

```bash
tccutil reset Accessibility com.benn.better-faster-shorter
launchctl kickstart -k gui/$UID/com.benn.better-faster-shorter
```

## License

[MIT](LICENSE)
