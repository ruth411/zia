# Zia - AI Personal Assistant for macOS

A native macOS menu bar AI assistant that helps manage your daily digital life. Built with SwiftUI and powered by Claude (Anthropic) or OpenAI.

## Features

- **AI Chat** - Conversational assistant powered by Claude or OpenAI (your choice)
- **Calendar & Reminders** - Native macOS Calendar and Reminders integration
- **Spotify Control** - Music playback control via Spotify API
- **Flight Tracking** - Track flights from email confirmations
- **Persistent Memory** - AI learns from your conversations and remembers preferences
- **Privacy First** - All data stored locally on your Mac

## Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- An AI API key (one of):
  - [Claude API key](https://console.anthropic.com/) (Anthropic)
  - [OpenAI API key](https://platform.openai.com/) (OpenAI)
- (Optional) [Spotify Developer credentials](https://developer.spotify.com/dashboard)

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Zia.git
   cd Zia
   ```

2. **Open in Xcode**
   ```bash
   open Zia.xcodeproj
   ```

3. **Build and run** (Cmd+R)

4. **First launch** - The onboarding wizard will guide you through:
   - Choosing your AI provider (Claude or OpenAI)
   - Entering your API key
   - (Optional) Setting up Spotify integration

## Spotify Setup (Optional)

To enable music control:

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create a new app
3. Set the redirect URI to: `com.ruthwikdovala.zia://oauth2callback`
4. Copy your Client ID and Client Secret
5. Enter them during the onboarding Spotify step

### Alternative: Secrets.plist (for development)

For convenience during development, you can create a `Secrets.plist` file:

1. Copy `Zia/Secrets.plist.example` to `Zia/Secrets.plist`
2. Fill in your Spotify credentials
3. The file is gitignored and will not be committed

## Architecture

```
Zia/
├── Core/
│   ├── Configuration.swift        # Central config (endpoints, layout constants)
│   └── DependencyContainer.swift  # Dependency injection
├── AI/
│   ├── AIProvider.swift           # Protocol for AI services
│   ├── ClaudeService.swift        # Claude API client
│   ├── OpenAIService.swift        # OpenAI API client
│   ├── AIServiceFactory.swift     # Provider selection factory
│   ├── ConversationManager.swift  # Chat history + persistence
│   └── Models/                    # Request/response models
├── Services/
│   ├── Authentication/
│   │   ├── OAuthProvider.swift    # OAuth protocol
│   │   ├── SpotifyOAuthProvider.swift
│   │   ├── AuthenticationManager.swift
│   │   ├── AppleSignInService.swift
│   │   └── KeychainService.swift  # Local credential storage
│   └── Storage/
│       ├── ConversationStore.swift    # Persistent chat history
│       └── UserPreferencesStore.swift # Learned preferences
└── UI/
    ├── Views/
    │   ├── MainView.swift         # Root view (onboarding or dashboard)
    │   ├── SettingsView.swift     # Settings panel
    │   ├── Onboarding/            # First-run setup wizard
    │   └── Dashboard/             # Dashboard components
    └── ViewModels/
        ├── ChatViewModel.swift
        └── DashboardViewModel.swift
```

## Data Storage

All data is stored locally in `~/Library/Application Support/com.ruthwikdovala.Zia/`:

| Data | Location | Format |
|------|----------|--------|
| API keys | UserDefaults | Encrypted via app sandbox |
| OAuth tokens | UserDefaults | JSON-encoded |
| Conversations | `conversations/` | JSON files |
| Preferences | `preferences.json` | JSON |

No data is shared between users or sent to any server other than the AI provider you chose.

## Multi-User Isolation

Each macOS user account has completely isolated data:
- Separate `~/Library/Application Support/` directory
- Separate `UserDefaults` domain
- Own API keys and OAuth tokens
- Independent conversation history and preferences

## Enterprise Roadmap

The architecture is designed to support future enterprise features:

- **Backend integration** - `AIProvider` protocol allows swapping to a proxy service
- **User identity** - Apple ID sign-in ready for backend authentication
- **Cloud sync** - `ConversationStore` can be extended with cloud sync
- **Team features** - Shared calendars, centralized API key management

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'feat: add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.
