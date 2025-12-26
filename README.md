# ArgusAI iOS App

iPhone prototype app for ArgusAI home security system.

## Overview

This SwiftUI prototype demonstrates core mobile connectivity for ArgusAI:

- **Device Pairing**: 6-digit code entry for secure device registration
- **Event Viewing**: Browse and view security events with AI descriptions
- **Push Notifications**: Receive alerts when events are detected
- **Local Discovery**: Automatically connect to local ArgusAI via Bonjour

## Requirements

- **iOS 17.0+**
- **Xcode 15.0+**
- **macOS 14 (Sonoma)+**
- **Apple Developer Account** (required for push notifications on device)

## Project Structure

```
ios-app/
├── ArgusAI/
│   ├── ArgusAIApp.swift           # App entry point
│   ├── Models/
│   │   ├── Event.swift            # Event model
│   │   ├── Camera.swift           # Camera model
│   │   └── AuthToken.swift        # Auth token models
│   ├── Services/
│   │   ├── APIClient.swift        # HTTP client with retry logic
│   │   ├── AuthService.swift      # Authentication/pairing
│   │   ├── KeychainService.swift  # Secure credential storage
│   │   ├── PushService.swift      # APNS handling
│   │   └── DiscoveryService.swift # Bonjour local discovery
│   ├── Views/
│   │   ├── PairingView.swift      # Device pairing screen
│   │   ├── EventListView.swift    # Event list with thumbnails
│   │   ├── EventDetailView.swift  # Event detail view
│   │   └── ErrorView.swift        # Error states
│   ├── ViewModels/
│   │   ├── PairingViewModel.swift
│   │   ├── EventListViewModel.swift
│   │   └── EventDetailViewModel.swift
│   └── Resources/
│       └── Info.plist
├── ArgusAITests/
│   ├── ViewModels/
│   │   ├── PairingViewModelTests.swift
│   │   └── EventListViewModelTests.swift
│   └── Services/
│       └── APIClientTests.swift
└── README.md
```

## Setup

### 1. Create Xcode Project

Since this is a prototype, you'll need to create the Xcode project:

1. Open Xcode
2. Create a new project: **File > New > Project**
3. Select **iOS > App**
4. Configure:
   - Product Name: `ArgusAI`
   - Team: Your Apple Developer Team
   - Organization Identifier: `com.argusai`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Minimum Deployment: **iOS 17.0**

5. Add the source files from this directory to your project
6. Configure signing with your Apple Developer account

### 2. Configure Push Notifications

1. Enable **Push Notifications** capability in Xcode
2. Enable **Background Modes > Remote notifications**
3. Generate APNS certificates/keys in Apple Developer Portal
4. Configure your ArgusAI backend with APNS credentials

### 3. Configure Cloud Relay (Optional)

Edit `DiscoveryService.swift` to set your cloud relay URL:

```swift
var cloudRelayURL: String = "https://your-argusai-instance.example.com"
```

### 4. Run on Device

Push notifications require a physical device:

1. Connect your iPhone
2. Select your device in Xcode
3. Build and run

## Architecture

### Authentication Flow

1. User opens app → PairingView shown
2. User gets 6-digit code from ArgusAI web dashboard
3. User enters code in app
4. App calls `/api/v1/mobile/auth/verify` with code + device ID
5. Server returns JWT tokens (access + refresh)
6. Tokens stored in iOS Keychain
7. App shows EventListView

### Token Refresh

- Access tokens expire after 1 hour
- Refresh tokens expire after 30 days
- APIClient automatically refreshes tokens before they expire
- Refresh tokens are rotated on each use

### Network Priority

1. **Local Discovery**: App searches for `_argusai._tcp.local` via Bonjour
2. **Local Connection**: If found, API calls go directly to local ArgusAI
3. **Cloud Relay**: If not found, falls back to configured cloud relay URL

### Push Notifications

- App registers for push on launch
- Device token sent to backend via `/api/v1/mobile/push/register`
- Backend sends push notifications with event_id in payload
- Tapping notification opens the relevant event

## Key Patterns

### @Observable (iOS 17+)

ViewModels use the `@Observable` macro for automatic UI updates:

```swift
@Observable
final class EventListViewModel {
    var events: [EventSummary] = []
    var isLoading = false
}
```

### Environment for DI

Services are injected via SwiftUI environment:

```swift
// In App
.environment(authService)
.environment(discoveryService)

// In View
@Environment(AuthService.self) private var authService
```

### Async/Await

All network operations use Swift concurrency:

```swift
func loadEvents(authService: AuthService) async {
    do {
        let client = APIClient(authService: authService)
        let response = try await client.fetchEvents()
        events = response.events
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

## Testing

Run tests in Xcode:

1. **Cmd+U** to run all tests
2. Or select specific test files in Test Navigator

### Test Coverage

- `PairingViewModelTests`: Code validation, filtering, state management
- `EventListViewModelTests`: Model parsing, display names
- `APIClientTests`: JSON decoding, error handling

## Prototype Limitations

This is a prototype for architecture validation. Not included:

- [ ] Full UI polish and animations
- [ ] iPad layout adaptations
- [ ] Apple Watch app
- [ ] Apple TV app
- [ ] macOS app
- [ ] Video playback
- [ ] Settings screen (minimal)
- [ ] Camera live view
- [ ] Offline mode/caching
- [ ] App Store preparation
- [ ] Certificate pinning (production)

## API Reference

See `docs/api/mobile-api.yaml` for complete API specification.

### Key Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /auth/pair` | Generate pairing code |
| `POST /auth/verify` | Verify code, get tokens |
| `POST /auth/refresh` | Refresh access token |
| `GET /events` | List events with pagination |
| `GET /events/{id}` | Get event detail |
| `GET /events/{id}/thumbnail` | Get event thumbnail |
| `GET /cameras` | List cameras |
| `POST /push/register` | Register for push notifications |

## Related Documentation

- [Mobile API Specification](../docs/api/mobile-api.yaml)
- [Cloud Relay Architecture](../docs/architecture/cloud-relay-design.md)
- [Apple Technology Research](../docs/research/apple-apps-technology.md)

## License

MIT License - See repository root for details.

---

*Generated as part of Story P8-4.4: Prototype iPhone App Structure*
