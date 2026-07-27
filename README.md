# Better, Faster, Shorter

*A better way to post shorter URLs, faster*

Ain't nobody wants to share a link that looks like this:

https://www.nytimes.com/2026/07/25/us/politics/some-article.html?campaign_id=60&emc=edit_na_20260725&instance_id=179334&nl=breaking-news&regi_id=52297349&segment_id=223691&user_id=c9acd82e34c2d4495e28bd852647882b

You want to share a link that looks this:

https://www.nytimes.com/2026/07/25/us/politics/some-article.html

This is a very silly little utility that makes that easy:

- `⌘V` - paste
- `⌘⇧V` - paste without formatting. We love this.
- NEW NEW FUN YAY `⌘⌥V` - paste, but if you're pasting a url, it'll scrub all the nonsense at the end.

(What happens if you use it to paste something that isn't a URL? It'll just paste normally. I think. But it might sometimes do something weird. I dunno, a robot built this; I have no idea how it works.)

## What it strips (and keeps)

It strips all the query params in a URL (usually, the stuff after the `?`) except for a few that are important:

| Kept  | Why                          |
|-------|------------------------------|
| `q`   | search queries               |
| `v`   | YouTube video ids            |
| `t`   | timestamps ("start at 0:42") |
| `list`| YouTube playlists            |
| `id`, `p`, `page` | generic resource ids and pagination |

This list probably needs to be longer. If I remember I have this app and keep using it, I'm sure I'll make it longer when I use it, strip out soemthing important, and something terrible happens. (To keep additional parameters, add them to `functionalParams` in [Sources/main.swift](Sources/main.swift) and rerun `./install.sh`.)

Oh, also - other stuff at the end of a URL is generally preserved, like the `#:~:text=` link-to-highlight fragments.

## Install

(*This is what the AI wrote.*)

Requires macOS 13+ and Xcode command line tools (`xcode-select --install`).

```bash
git clone https://github.com/bstancil/better-faster-shorter.git
cd better-faster-shorter
./install.sh
```

This compiles the app (a single Swift file, no dependencies), installs it to `~/Applications/Better, Faster, Shorter.app`, and registers a launch agent so it starts at login. It runs invisibly — no menu bar icon, no dock icon.

**One manual step:** macOS will prompt for Accessibility access (the app needs it to simulate the paste keystroke). Click "Open System Settings" and toggle Better, Faster, Shorter on. Without this, ⌘⌥V does nothing.

## Uninstall

```bash
launchctl bootout gui/$UID/com.benn.better-faster-shorter
rm ~/Library/LaunchAgents/com.benn.better-faster-shorter.plist
rm -rf ~/Applications/"Better, Faster, Shorter.app"
```

## How it works

- Registers ⌘⌥V as a global hotkey (Carbon `RegisterEventHotKey`).
- On press, if the clipboard is an http(s) URL: saves the clipboard, writes the cleaned URL, posts a synthetic ⌘V keystroke, then restores the original clipboard ~0.6 seconds later unless you've copied something else.
- Clipboard contents never leave your machine or get written to disk. There's no network access, and logging is off by default (a status-only debug log can be enabled in the source by setting `loggingEnabled = true`).

## WARNINGS and caveats

- AI machines wrote all of this, obviously. I'm just here to tell you about it.
- **⌘⌥V is Finder's "Move item here" shortcut.** (I don't know what this is, but the AI machines are worried about it.) This app overrides it system-wide. If you use that, change the combo in `registerHotKey()` in [Sources/main.swift](Sources/main.swift) (e.g. add `shiftKey`).
- Apps with non-standard paste handling (some terminals, VMs) may ignore the synthetic keystroke. But also, if you're pasting links in your terminal, it's probably fine if they're ugly.
- **Rebuilds may reset the Accessibility grant.** `install.sh` signs with the first code-signing identity in your keychain, which keeps the permission stable across rebuilds. With no identity available it falls back to ad-hoc signing, and macOS ties the grant to the exact binary — after a rebuild, toggle the app off and on again in System Settings → Privacy & Security → Accessibility.