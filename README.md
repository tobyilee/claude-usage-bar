# Claude Usage Bar

A small macOS menubar app that shows your current Claude Code usage at a glance — 5-hour session %, weekly all-models %, and weekly Sonnet-only %, plus time until each limit resets.

## Why

Claude Code (Pro / Max) has session and weekly usage limits. This app lives in your menubar so you can pace work without opening claude.ai.

Unlike alternatives that scrape the claude.ai web page through a hidden webview, this calls the official OAuth-protected endpoint at `api.anthropic.com/api/oauth/usage` directly, using the OAuth token Claude Code already wrote to your macOS Keychain — no separate login, no scraping, ~365 KB binary.

## Features

- 5-hour session %, weekly all-models %, weekly Sonnet-only %, with time-to-reset
- Plan tier (Pro / Max) shown in the popover header when the API exposes it
- Threshold-tinted gauge icon: gray → yellow (50%) → orange (80%) → red (95%)
- Auto-refresh every 60 s; manual refresh button in the popover
- Token auto-refresh — the app calls Anthropic's OAuth refresh endpoint when the access token nears expiry or a 401 comes back, then writes the new tokens back to the same Keychain item so `claude` itself stays signed in
- Graceful 420 / 429 rate-limit backoff (honors `Retry-After`, defaults to 5 min)
- LaunchAgent-based auto-start at login

## Requirements

- macOS 14 (Sonoma) or later
- Claude Code CLI installed and signed in (`claude` once)

## Install

```bash
git clone https://github.com/<your-username>/claude-usage-bar.git
cd claude-usage-bar
./install.sh
```

`install.sh` builds a release `.app`, copies it to `/Applications`, and registers a LaunchAgent at `~/Library/LaunchAgents/com.tobylee.ClaudeUsageBar.plist`. On first launch, click **Always Allow** when macOS asks for keychain access.

## Build only (no install)

```bash
swift run                     # dev loop — fast, brief Dock-icon flash on launch
make app                      # release build → build/ClaudeUsageBar.app
make install                  # copies build/ClaudeUsageBar.app → /Applications/
```

## Uninstall

```bash
launchctl bootout "gui/$(id -u)/com.tobylee.ClaudeUsageBar"
rm -f ~/Library/LaunchAgents/com.tobylee.ClaudeUsageBar.plist
rm -rf /Applications/ClaudeUsageBar.app
```

## How it works

1. Reads OAuth credentials from the macOS Keychain (`Claude Code-credentials` service, `claudeAiOauth.accessToken` field) via `SecItemCopyMatching`.
2. Calls `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <token>` and `anthropic-beta: oauth-2025-04-20`.
3. If the access token is near expiry or the call returns 401, the app refreshes via `POST https://console.anthropic.com/v1/oauth/token` using the public Claude Code CLI `client_id`, and writes the rotated tokens back to the same Keychain item (via `SecItemUpdate` — preserves the item's creation attributes so `claude` keeps trusting it).
4. Parses `five_hour`, `seven_day`, `seven_day_sonnet` buckets and renders them in a SwiftUI `MenuBarExtra` popover.

## Architecture

| File | Role |
| --- | --- |
| `ClaudeUsageBarApp.swift` | `@main`, `MenuBarExtra` wiring |
| `AppDelegate.swift` | sets `NSApp.setActivationPolicy(.accessory)` (no Dock icon at runtime) |
| `UsageStore.swift` | `@Observable @MainActor` store with the polling loop, manual-refresh wakeup, and rate-limit cooldown |
| `KeychainCredentials.swift` | `SecItemCopyMatching` / `SecItemUpdate` |
| `AnthropicClient.swift` | three HTTPS calls (usage, profile, refresh-token) + 420/429 handling |
| `UsageModels.swift` | `Codable` structs + flexible date decoder (ISO-8601 / unix-s / unix-ms) |
| `MenubarLabel.swift` | gauge SF Symbol + percent text in the menubar |
| `PopoverView.swift` | three usage rows + footer with refresh / quit |
| `UsageRow.swift` | one usage row (icon + title + bar + reset time) |
| `Formatters.swift` | "1h 42m" / "12s ago" via `DateComponentsFormatter` |

## License

MIT
