# Better, Faster, Shorter

*A better way to post shorter URLs, faster.*

Ain't nobody wants to links that look like this:

https://www.nytimes.com/2026/07/25/us/politics/some-article.html?campaign_id=60&emc=edit_na_20260725&instance_id=179334&nl=breaking-news&regi_id=52297349&segment_id=223691&user_id=c9acd82e34c2d4495e28bd852647882b

It's ugly! It's long! It shows people that you got the link from ChatGPT! It breaks the _New York Times'_ careful tracking of its traffic sources!

We want to share links that looks this:

https://www.nytimes.com/2026/07/25/us/politics/some-article.html

This is a very silly little utility that makes that easy. Install it, and your computer will do wonderous things:

- `⌘V` - paste.
- `⌘⇧V` - paste without formatting. It already does this. Maybe you didn't know. If you didn't, excellent, you've now learned something that's way more useful than what this app does.
- `⌘⌥V` FUN NEW THIS IS THE WHOLE APP - paste, but if you're pasting a url, it'll scrub all of that nonsense at the end.

That's it. That's the whole thing. A third way to paste.

## What it removes

It strips all the query params in a URL (usually, the stuff after the `?`) except for a few that are important:

| Kept  | Why                          |
|-------|------------------------------|
| `q`   | search queries               |
| `v`   | YouTube video ids            |
| `t`   | timestamps ("start at 0:42") |
| `list`| YouTube playlists            |
| `id`, `p`, `page` | generic resource ids and pagination |

This list is too short. It probably needs to be longer, and maybe smarter. If I remember to use this app, I'm sure I'll find all sorts of other things that the app should keep, and I'll add them to the list. (You can add things too, by adding them to `functionalParams` in [Sources/main.swift](Sources/main.swift) and reinstalling the app.)

Oh, also - some other stuff at the end of a URL is generally preserved, like the `#:~:text=` link-to-highlight thing that Chrome supports.

---

(*This is the part the AI machine wrote. Oh, this, and all of the code, which I obviously haven't read. Install this at your own risk.*)

## How to install it

Requires macOS 13+ and Xcode command line tools (`xcode-select --install`).

```bash
git clone https://github.com/bstancil/better-faster-shorter.git
cd better-faster-shorter
./install.sh
```

This compiles the app (a single Swift file, no dependencies), installs it to `~/Applications/Better, Faster, Shorter.app`, and registers a launch agent so it starts at login. It runs invisibly — no menu bar icon, no dock icon.

**Note:** macOS will prompt for Accessibility access (the app needs it to simulate the paste keystroke). Click "Open System Settings" and toggle Better, Faster, Shorter on. Without this, ⌘⌥V does nothing.

## How to uninstall it

```bash
launchctl bootout gui/$UID/com.benn.better-faster-shorter
rm ~/Library/LaunchAgents/com.benn.better-faster-shorter.plist
rm -rf ~/Applications/"Better, Faster, Shorter.app"
```

## How it works

- It registers `⌘⌥V` as a global hotkey (Carbon `RegisterEventHotKey`).
- On press, if the clipboard is an http(s) URL: saves the clipboard, writes the cleaned URL, posts a synthetic ⌘V keystroke, then restores the original clipboard ~0.6 seconds later unless you've copied something else.
- Clipboard contents never leave your machine or get written to disk. There's no network access, and logging is off by default (a status-only debug log can be enabled in the source by setting `loggingEnabled = true`).

## Warnings and caveats

- **⌘⌥V is Finder's "Move item here" shortcut.** _[I've certainly never used this shortcut before, but the AI machines are worried about it.]_ This app overrides it system-wide. If you use that, change the combo in `registerHotKey()` in [Sources/main.swift](Sources/main.swift) (e.g. add `shiftKey`).
- **It might not work with some apps.** Apps with non-standard paste handling (some terminals, VMs) may ignore the synthetic keystroke. _[But also, if you're pasting links in your terminal, it's probably fine if they're ugly. Just use `⌘V`.]_
- **Rebuilds may reset the Accessibility grant.** `install.sh` signs with the first code-signing identity in your keychain, which keeps the permission stable across rebuilds. With no identity available it falls back to ad-hoc signing, and macOS ties the grant to the exact binary — after a rebuild, toggle the app off and on again in System Settings → Privacy & Security → Accessibility.