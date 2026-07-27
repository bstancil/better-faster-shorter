#!/bin/zsh
# Build "Better, Faster, Shorter", install it to ~/Applications, and set it
# to run at login.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Better, Faster, Shorter"   # display name (.app folder)
EXEC=BetterFasterShorter             # executable inside the bundle
BUNDLE_ID=com.benn.better-faster-shorter
BUNDLE="build/$APP_NAME.app"
INSTALLED="$HOME/Applications/$APP_NAME.app"
PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

echo "Building..."
rm -rf build
mkdir -p "$BUNDLE/Contents/MacOS"
swiftc -O Sources/main.swift -o "$BUNDLE/Contents/MacOS/$EXEC"
cp Info.plist "$BUNDLE/Contents/Info.plist"
mkdir -p "$BUNDLE/Contents/Resources"
cp AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
# Prefer a real signing identity (stable across rebuilds, so the
# Accessibility grant survives); fall back to ad-hoc.
SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' 'NR == 1 { print $2; exit }') || SIGN_ID=
SIGN_ID=${SIGN_ID:--}
codesign --force --options runtime --sign "$SIGN_ID" "$BUNDLE" 2>/dev/null \
  || codesign --force --sign "$SIGN_ID" "$BUNDLE"

echo "Installing to $INSTALLED..."
launchctl bootout "gui/$UID/$BUNDLE_ID" 2>/dev/null || true
pkill -x "$EXEC" 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$INSTALLED"
cp -R "$BUNDLE" "$INSTALLED"

echo "Setting up launch agent..."
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$BUNDLE_ID</string>
	<key>ProgramArguments</key>
	<array>
		<string>$INSTALLED/Contents/MacOS/$EXEC</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
</dict>
</plist>
EOF
launchctl bootstrap "gui/$UID" "$PLIST"

echo "Done. If macOS prompts for Accessibility access, grant it to \"$APP_NAME\""
echo "(System Settings > Privacy & Security > Accessibility)."
