<div align="center">
  <h1>Zia</h1>
  <p>Native macOS menu bar AI assistant — 23 built-in tools, local-only privacy, bring your own API key.</p>

  ![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)
  ![Swift](https://img.shields.io/badge/Swift-5.10-orange)
  ![License](https://img.shields.io/badge/license-MIT-green)
</div>

---

## What is Zia?

Zia lives in your menu bar and gives you a conversational interface to your entire Mac. Ask it to create calendar events, control Spotify, run shell commands, capture your screen, search the web, read and write files — all without leaving the keyboard.

It is powered by the [Claude API](https://console.anthropic.com/) (Anthropic). You bring your own API key — Zia never routes your data through any third-party server. Everything stays on your Mac.

---

## Features

### Core
- **Conversational AI** — Claude-powered chat with full tool-use (agentic loop, up to 10 iterations)
- **Global Hotkey** — ⌘+Shift+Z opens Zia from anywhere
- **RAG Search** — Zia remembers past conversations using a local SQLite FTS5 index
- **Automations** — Schedule recurring AI tasks (daily briefings, reminders, etc.)
- **MCP Support** — Extend Zia with custom tools via `~/.zia/mcp.json`

### Built-in Tools (23 total)

| Category | Tools |
|----------|-------|
| **System** | Get date/time, system info, set default browser |
| **Calendar** | Get events, create event, delete event |
| **Reminders** | List, create, complete reminders |
| **Spotify** | Now playing, play/pause, skip, search, play track |
| **Shell** | Run shell commands, run AppleScript |
| **File System** | Read file, write file, list directory |
| **Web** | Fetch URL content |
| **Clipboard** | Read and write clipboard |
| **Utility** | Open URL |
| **Vision** | Screen capture (full screen or focused window) |
| **Automations** | Create, list, run, delete scheduled automations |

### Privacy
- No account required — just your own API key
- All conversations stored locally in `~/Library/Application Support/`
- No analytics, no telemetry, no cloud sync

---

## Installation

### Download (Recommended)

1. Download `Zia-v1.0.dmg` from the [Releases](../../releases) page
2. Open the DMG → drag **Zia** to your **Applications** folder
3. **Right-click Zia.app → Open → Open**
   > Zia is not signed with a paid Apple Developer certificate, so macOS will show a
   > "cannot be verified" warning on first launch. Right-clicking → Open bypasses this.
   > After the first launch, it opens normally.
4. Enter your [Anthropic API key](https://console.anthropic.com/) in the setup screen

### Build from Source

**Requirements:** macOS 14.0+, Xcode 15.4+

```bash
git clone https://github.com/YOUR_USERNAME/Zia.git
cd Zia/Zia
open Zia.xcodeproj
```

Press **⌘R** in Xcode to build and run.

---

## First-Launch Permissions

| Feature | Permission | How it's granted |
|---------|-----------|-----------------|
| Calendar & Reminders | Privacy → Calendars / Reminders | Auto-prompted on first use |
| Microphone (voice input) | Privacy → Microphone | Auto-prompted on first use |
| AppleScript / Shell | Privacy → Automation | Auto-prompted on first use |
| Screen Capture (⌘+Shift+Z) | Privacy → Screen Recording | **Must be enabled manually** |

**Screen Recording:** System Settings → Privacy & Security → Screen Recording → find Zia → toggle ON → relaunch Zia.

---

## Spotify Setup (Optional)

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create an app → set Redirect URI to `com.ruthwikdovala.zia://oauth2callback`
3. Copy your **Client ID** and **Client Secret**
4. In Zia: Settings → Connected Services → Spotify → Connect

**Dev shortcut:** copy `Zia/Secrets.plist.example` → `Zia/Secrets.plist`, fill in credentials. This file is gitignored.

---

## MCP Servers

Zia supports the [Model Context Protocol](https://modelcontextprotocol.io/) — add any MCP server to extend Zia with custom tools.

Create `~/.zia/mcp.json`:

```json
{
  "mcpServers": {
    "my-tool": {
      "command": "npx",
      "args": ["-y", "@my-org/mcp-server"]
    }
  }
}
```

Then: Zia → Settings → MCP Servers → **Reload MCP Config**.

---

## Architecture

```
Zia/Zia/
├── AI/                   # Claude API client, ConversationManager, agent loop
├── Capabilities/         # All 23 tools
│   ├── Base/             # Tool protocol + ToolRegistry + ToolExecutor
│   ├── Calendar/
│   ├── FileSystem/
│   ├── Music/            # Spotify
│   ├── Shell/
│   ├── Vision/           # Screen capture
│   ├── Web/
│   ├── Automation/
│   └── Utility/
├── Core/                 # DependencyContainer, Configuration, HotkeyManager
├── Services/
│   ├── Authentication/   # Keychain, OAuth (Spotify)
│   ├── MCP/              # MCP client — connects to external tool servers
│   ├── RAG/              # SQLite FTS5 conversation search index
│   ├── Voice/            # Speech recognition + synthesis
│   ├── Automation/       # Scheduled automation engine
│   └── Scheduling/       # Proactive triggers (morning briefing, etc.)
└── UI/
    ├── MenuBar/          # NSStatusItem — menu bar icon + popover
    ├── ViewModels/       # ChatViewModel, DashboardViewModel
    └── Views/            # Dashboard, Onboarding, Settings
```

**Key design decisions:**
- Single `DependencyContainer.shared` wires all services at launch
- All tools conform to the `Tool` protocol and are registered in `DependencyContainer.registerAllTools()`
- The agent loop in `ChatViewModel.sendMessage()` calls Claude, executes tool results, and loops until done
- RAG uses SQLite FTS5 (keyword search) over conversation history — fast, local, no embeddings needed
- Keychain stores all credentials (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)

---

## Data Storage

Everything lives on your Mac:

| Data | Location | Format |
|------|----------|--------|
| Conversations | `~/Library/Application Support/com.ruthwikdovala.Zia/` | JSON |
| RAG index | `~/Library/Application Support/com.ruthwikdovala.Zia/` | SQLite |
| API keys / tokens | macOS Keychain | Encrypted |
| Automations | `~/.zia/automations.json` | JSON |
| MCP config | `~/.zia/mcp.json` | JSON |

---

## Development

```bash
# Build (Debug)
xcodebuild -project Zia.xcodeproj -scheme Zia -configuration Debug build

# Run tests
xcodebuild test -project Zia.xcodeproj -scheme Zia -only-testing:ZiaTests

# Build Release binary
xcodebuild -project Zia.xcodeproj -scheme Zia -configuration Release \
  -derivedDataPath /tmp/ZiaBuild build
```

**Adding a new tool:**
1. Create a struct conforming to `Tool` in `Capabilities/`
2. Register it in `DependencyContainer.registerAllTools()`
3. Add a test in `ZiaTests/ZiaTests.swift`

---

## Contributing

1. Fork the repo
2. Create a branch: `git checkout -b feature/my-feature`
3. Commit: `git commit -m 'feat: add my feature'`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

Please run the test suite before submitting (`xcodebuild test`).

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

<div align="center">
  <sub>Built for macOS with Swift and SwiftUI. Claude AI assistance was used during development to improve code quality and accelerate iteration.</sub>
</div>

