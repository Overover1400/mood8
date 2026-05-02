# Mood8 — AI-Powered Personal Operating System

## Project Vision
Mood8 is NOT another habit tracker. It's an AI-powered personal operating system 
that learns user patterns, adapts routines, and shows what actually makes them better.

## Positioning
- ❌ NOT: "Habit Tracker"
- ❌ NOT: "Self-Improvement App"
- ✅ YES: "Understand what actually improves YOUR life"

## Tech Stack
- **Frontend:** Flutter (Web + Android + iOS + Desktop + Wear OS)
- **watchOS:** Native Swift + SwiftUI (separate project)
- **State:** Provider/Riverpod (TBD)
- **Storage:** Hive (local) + Supabase (cloud sync, later)
- **AI:** Claude API (for AI Coach)

## Build Targets (Priority Order)
1. ✅ Web (primary, fastest iteration)
2. Android
3. iOS (via cloud build)
4. watchOS (Swift, separate)
5. Desktop (Mac/Windows/Linux)

## Design System

### Colors (Dark Theme - Purple/Pink)

--bg-deep:     #0A0612  (main background)
--bg:          #110821  (secondary)
--bg-card:     #1F1338  (cards)
--purple:      #A855F7  (primary brand)
--purple-light:#C084FC  (hover)
--pink:        #EC4899  (secondary)
--pink-light:  #F472B6  (soft accent)
--blue-accent: #818CF8  (tertiary)
--ink:         #FAF5FF  (primary text)
--ink-soft:    #E9D5FF  (secondary text)
--ink-dim:     #A78BB8  (tertiary text)
--ink-faint:   #6B5680  (disabled)

### Gradients
- **Primary:** Purple → Pink → Pink-light (135deg)
- **Button:** Purple-light → Pink-light → Blue-accent
- **Soft:** Purple 15% → Pink 15%
- **Orb:** Radial purple/pink (animated)

### Typography
- **Display/Headlines:** Instrument Serif (italic for emphasis)
- **Body/UI:** Plus Jakarta Sans
- **Use google_fonts package**

## Folder Structure


lib/
├── main.dart
├── theme/
│   └── app_theme.dart
├── widgets/
│   ├── mood_orb.dart
│   ├── glow_slider.dart
│   ├── cards.dart
│   └── bottom_nav.dart
├── screens/
│   └── home_screen.dart
├── models/        (data classes)
└── services/      (storage, API)




## Home Screen Specifications

### Layout (top to bottom):
1. **Header:** Date + greeting + streak count
2. **Mood Hero Card:** "How are you, right now?" with 3 sliders (Mood, Energy, Focus)
3. **Save Check-in Button:** Gradient pill button
4. **Stats Row:** 3 cards (Streak 🔥, Today ⚡, Score ✨)
5. **Up Next Section:** Routine cards with NOW indicator
6. **Bottom Nav:** 5 items (Today, Habits, Routine, Insights, Progress)

### Animations:
- Use `flutter_animate` package
- Fade-in + slide-up on screen load
- Mood orb floats and pulses continuously
- Smooth transitions on slider drag

## Coding Standards
- Use `const` constructors when possible
- Extract reusable widgets
- Keep widgets under 200 lines
- Use meaningful variable names
- Comment complex logic only

## Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter: { sdk: flutter }
  cupertino_icons: ^1.0.6
  google_fonts: ^6.1.0
  flutter_animate: ^4.5.0
  intl: ^0.19.0
```

## Wear OS Support
The app will run on:
- Samsung Galaxy Watch 4+
- Google Pixel Watch
- All Wear OS 3+ devices

Wear OS specifics:
- Round screens (most watches)
- Square screens (some Galaxy variants)
- Small screens (192-454px diameter)
- Touch + rotating bezel/crown input
- Always-On Display support needed
- Battery efficiency critical

Code lives in:
- lib/wear/ folder for Wear-specific UI
- Shared models with phone app
- Separate entry point: lib/main_wear.dart

## Don't Do
- ❌ NO social features (no feeds, communities)
- ❌ NO meditation libraries
- ❌ NO complex onboarding
- ❌ NO childish gamification (coins, gems)
- ❌ NO over-formatting in UI

## Do
- ✅ Identity-based progress (Atomic Habits style)
- ✅ Ultra-fast logging (< 3 seconds)
- ✅ AI insights from correlation
- ✅ Adaptive routines
- ✅ Premium feel (editorial typography)

## Server Constraints
- RAM: 1.7GB + 4GB swap = ~5.7GB
- Disk: ~3.9GB free
- Use `flutter run -d web-server` for testing
- Avoid Android builds on this server (use GitHub Actions)
