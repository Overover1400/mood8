# Mood8 — watchOS App

Native Swift / SwiftUI companion to the Flutter Mood8 app. Lives in this folder
because it's a separate Xcode project, intentionally decoupled from the Flutter
codebase (Flutter on watchOS isn't viable, and a native build keeps complications,
Digital Crown input, and haptics first-class).

## Status

Source is scaffolded. The Xcode project file (`Mood8.xcodeproj`) is **not yet
committed** — see [Setup](#setup) below to generate it.

## Requirements

| Tool       | Version          |
|------------|------------------|
| macOS      | 14 (Sonoma) or newer |
| Xcode      | 15.0+            |
| watchOS SDK | 10.0+ minimum deployment target |
| Swift      | 5.9+ (SwiftUI 5) |

A physical Apple Watch is **not** required for development — the watchOS
simulator covers all sizes (40/41/44/45mm + 49mm Ultra).

## Folder layout

```
ios_watch/
├── Mood8.xcodeproj/                    (NOT YET CREATED — see Setup)
├── Mood8WatchApp/
│   ├── Mood8App.swift                  App entry; injects DataStore
│   ├── Theme/
│   │   ├── Colors.swift                Brand palette (#A855F7 → #EC4899)
│   │   └── Gradients.swift             Linear & radial gradients
│   ├── Views/
│   │   ├── HomeView.swift              Greeting + orb + quick log + nav chips
│   │   ├── MoodCheckInView.swift       3 sliders + save (target <3s)
│   │   ├── StreakView.swift            Big serif "47" with identity line
│   │   ├── RoutineView.swift           Today's routine (hardcoded for MVP)
│   │   └── Components/
│   │       ├── MoodOrb.swift           Animated radial-gradient orb
│   │       ├── GlowSlider.swift        Custom slider w/ Digital Crown + haptics
│   │       └── QuickButton.swift       Reusable gradient pill button
│   ├── Models/
│   │   └── MoodEntry.swift             Codable struct (mood, energy, focus 0–1)
│   ├── Services/
│   │   └── DataStore.swift             ObservableObject over UserDefaults
│   └── Complications/
│       └── StreakComplication.swift    WidgetKit complication (4 families)
└── README.md                           (this file)
```

## Design parity with the Flutter app

The `Theme/Colors.swift` and `Theme/Gradients.swift` files mirror
`lib/theme/app_theme.dart` exactly — every color and gradient stop is taken from
that source. **If you change the palette in one place, change it in the other.**

Typography:
- **Headlines:** SwiftUI's `.serif` design with `.italic()` — ships with the
  system, equivalent to Instrument Serif's vibe without bundling a font.
- **Body / UI:** SF Pro (default system font) — equivalent role to Plus Jakarta
  Sans on the Flutter side.

Animation:
- The mood orb runs continuously via `TimelineView(.animation)`.
- Sliders fire `.click` haptic per integer-tenth crossed; saves fire `.notification`.

## Setup

### 1. Create the Xcode project

The source files are ready, but the `.xcodeproj` is intentionally not in version
control yet (Xcode projects are noisy to edit by hand). Generate one:

1. Open Xcode → **File → New → Project...**
2. Choose **watchOS → App** (the standalone watchOS app template, not the
   "Watch App for iOS App" template — Mood8 does not require an iPhone host).
3. Product Name: `Mood8`
4. Organization Identifier: your reverse-DNS (e.g. `com.mood8`)
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Save the project **inside this `ios_watch/` directory** so the resulting
   structure is `ios_watch/Mood8.xcodeproj/`.

Xcode will scaffold its own `Mood8 Watch App/` folder. Delete the auto-generated
`ContentView.swift` and `Mood8App.swift` files inside it, then drag the existing
`Mood8WatchApp/` folder into the project navigator (choose "Create groups",
**not** "Create folder references", and add to the Watch App target).

### 2. Setting up complications

Complications run as a separate Widget Extension target. Add one:

1. **File → New → Target...**
2. Choose **watchOS → Widget Extension**
3. Product Name: `Mood8Widgets`
4. **Uncheck** "Include Configuration App Intent" (the streak doesn't need
   user-configurable parameters).
5. Once created, replace the default widget with the contents of
   `Complications/StreakComplication.swift`. Move that file into the
   `Mood8Widgets` target (uncheck it from the main app target).
6. **Uncomment** the `@main Mood8WidgetBundle` block at the bottom of that file.

#### App Group (required for the widget to read the user's data)

Both targets need an App Group entitlement so they share UserDefaults:

1. Select the project → **Mood8** target → **Signing & Capabilities** → **+ Capability** → **App Groups**.
2. Add a group: `group.com.mood8.shared`.
3. Repeat for the `Mood8Widgets` target — pick the same group.
4. In `DataStore.swift` and `StreakComplication.swift`, change
   `UserDefaults.standard` to:
   ```swift
   UserDefaults(suiteName: "group.com.mood8.shared")!
   ```
   (kept as `.standard` in the scaffold so the app builds before the App Group is set up).

### 3. Run

- **Simulator:** select any Apple Watch scheme (test all sizes — 40mm is the
  tightest layout target). ⌘R.
- **Device:** pair the watch with Xcode (requires a paired iPhone), select it
  as the run destination.

## Architecture notes

- **State:** single `DataStore` `ObservableObject` injected via `@EnvironmentObject`.
  No Redux/TCA — overkill for a 3-screen app.
- **Persistence:** UserDefaults with JSON-encoded `[MoodEntry]`. Versioned key
  (`mood8.entries.v1`) so future schema changes can migrate cleanly.
- **No network, no accounts** in the MVP. Cloud sync (Supabase) is a later
  iteration once the Flutter side has it too.

## What's intentionally missing (MVP scope)

- iPhone companion app — Mood8 watch runs standalone for now.
- WatchConnectivity — no iPhone yet, no need.
- HealthKit integration — planned but not in this cut.
- Notifications — the AI Coach will introduce these; not scoped here.
- AI Coach insights — Claude API integration belongs on iPhone/web first.

## Testing

Unit tests aren't included in this scaffold — `DataStore.currentStreak` is the
only piece with non-trivial logic and warrants a test once the Xcode project
exists. Add a `Mood8Tests` target and seed it with cases for: empty store,
single entry today, single entry yesterday, broken streak.
