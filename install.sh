#!/usr/bin/env bash
# Build ClaudeUsageBar, install it to /Applications, and configure auto-start at login.
#
# Re-run this script anytime to update the installed copy.
set -euo pipefail

APP_NAME="ClaudeUsageBar"
LABEL="com.tobylee.$APP_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/build/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_NUM="$(id -u)"

cd "$SCRIPT_DIR"

echo "==> 1/4  Building release .app bundle"
make app >/dev/null

echo "==> 2/4  Installing to $TARGET_APP"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1
rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"

echo "==> 3/4  Writing LaunchAgent plist  ($PLIST_PATH)"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET_APP/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
</dict>
</plist>
PLIST
chmod 0644 "$PLIST_PATH"

echo "==> 4/4  Loading and launching"
launchctl bootstrap "gui/$UID_NUM" "$PLIST_PATH"
launchctl kickstart -k "gui/$UID_NUM/$LABEL"

cat <<DONE

✓ Installed       $TARGET_APP
✓ Auto-start at   $PLIST_PATH
✓ Running now — check your menubar for the gauge icon.

The first launch will prompt for keychain access — click "Always Allow"
so future starts can read the Claude Code OAuth token without asking.

To uninstall:
  launchctl bootout "gui/\$(id -u)/$LABEL"
  rm -f "$PLIST_PATH"
  rm -rf "$TARGET_APP"
DONE
