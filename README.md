<div align="center">

# Mood8

### Become more of yourself

An AI-powered personal operating system that learns what actually makes you better.

[![Live](https://img.shields.io/badge/Live-mood8.app-A855F7?style=for-the-badge)](https://mood8.app)
[![Flutter](https://img.shields.io/badge/Flutter-3.30+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Web](https://img.shields.io/badge/Platform-Web%20%7C%20Android%20%7C%20Wear%20OS-EC4899?style=for-the-badge)](https://mood8.app)
[![License](https://img.shields.io/badge/License-Proprietary-FAF5FF?style=for-the-badge)](LICENSE)

[**Try it live →**](https://mood8.app) · [Landing page](https://mood8.app/landing/) · [Privacy](https://mood8.app/privacy.html) · [Terms](https://mood8.app/terms.html)

</div>

---

## ✨ What is Mood8?

Mood8 is a personal operating system for becoming who you want to be. Inspired by Atomic Habits and powered by AI, it learns your patterns and helps you align daily actions with your deepest identities.

Unlike generic habit trackers, Mood8 doesn't tell you what to do — it discovers what works for **you**, scientifically.

## 🌟 Key Features

### 🎯 Identity-Based Habits
Become someone, not just do something. Each habit votes for who you want to be — Athlete, Creator, Mindful soul, Scholar, Leader, or Parent.

### 🤖 AI Coach
Nightly reflections based on YOUR data. Chat anytime about your patterns. Like having a wise friend who's been paying attention. Powered by GPT-4o-mini.

### 🔬 Personal Insights
Statistical correlations + AI explanations discover what actually makes you better. "Walking 20+ min = +31% mood next day" — backed by YOUR data, not generic advice.

### 📊 Beautiful Progress
Charts, heatmaps, identity bars, discipline score. Watch yourself transform, day by day, with visualizations that make tracking actually enjoyable.

### 🔄 Adaptive Routine Engine
Mood8 analyzes your last 14 days and suggests improvements. "You skip morning routine when stressed — try a simpler version" — smart recommendations based on real patterns.

### ⌚ Wear OS Support
Native Wear OS app for Samsung Galaxy Watch and Pixel Watch. Quick check-ins right from your wrist.

### 🎨 Premium Design
Cinematic effects, smooth animations, glass morphism. Built to feel like Linear, Notion, and Apple — not generic.

## 🏗 Architecture

mood8/
├── lib/
│   ├── screens/          # 8 main screens (Home, Routine, Habits, Coach, Insights, Progress, Settings, Auth)
│   ├── widgets/          # Reusable components + effects
│   ├── models/           # Hive type adapters
│   ├── services/         # Business logic (AI, auth, scoring, adaptive engine)
│   ├── repositories/     # Data layer
│   └── theme/            # Design system
├── android/              # Android + Wear OS
├── web/                  # Web build + landing page
└── ios_watch/            # watchOS (paused - needs Mac)
mood8-backend/            # Python FastAPI server
├── main.py               # Auth + AI endpoints
├── database.py           # PostgreSQL models (User)
├── auth.py               # JWT + password helpers
└── email_service.py      # SMTP via Postfix



## 🛠 Tech Stack

**Frontend**
- Flutter 3.30+ (Web, Android, Wear OS)
- Hive 2.2 (local-first database)
- fl_chart (data visualization)
- audioplayers + flutter_animate
- flutter_secure_storage (JWT)

**Backend**
- Python 3.12 + FastAPI
- PostgreSQL 16 (user accounts)
- OpenAI API (gpt-4o-mini)
- SQLAlchemy + Pydantic
- JWT authentication
- Postfix SMTP relay (email)

**Infrastructure**
- Ubuntu 24.04
- Nginx + Let's Encrypt SSL
- systemd service management
- GitHub Actions (CI/CD)
- Custom domain: mood8.app

## 📱 Platforms

| Platform | Status |
|----------|--------|
| Web (PWA) | ✅ Live at [mood8.app](https://mood8.app) |
| Android | 🟡 APK builds via GitHub Actions |
| Wear OS | ✅ Released for Galaxy Watch / Pixel Watch |
| iOS | 🔵 Code ready, awaiting Mac build |
| Apple Watch | 🔵 Code ready, awaiting Mac build |

## 🔐 Privacy First

- ✅ Data stored **locally** in your browser/device
- ✅ End-to-end encrypted backups (coming soon)
- ✅ No analytics, no tracking, no ads
- ✅ Export your data anytime (JSON or CSV)
- ✅ Delete account = delete all data
- ✅ Open source (coming soon)

## 🚀 Roadmap

### Q2 2026 (Now)
- ✅ Core MVP with 8 screens
- ✅ AI Coach + Insights
- ✅ Email authentication
- ✅ Wear OS app
- 🟡 Beta testing
- 🟡 Public launch

### Q3 2026
- 📅 Multi-device sync (E2E encrypted)
- 📅 iOS + Apple Watch release
- 📅 Premium tier ($4.99/mo)
- 📅 Identity-specific AI coaching
- 📅 Community features (optional)

### Q4 2026
- 📅 Open source client
- 📅 Plugin system
- 📅 API for developers
- 📅 Advanced AI models

## 💎 Why "Mood8"?

The "8" is infinity sideways — endless growth. It also represents the 8 dimensions Mood8 tracks: **mood, energy, focus, routine, habits, identity, time, and self**.

## 👤 Creator

Built with 💜 by [Hamed Mostafaei](https://github.com/Overover1400) — a solo developer passionate about human potential and beautiful software.

Connect:
- 📧 [hello@mood8.app](mailto:hello@mood8.app)
- 🐛 [feedback@mood8.app](mailto:feedback@mood8.app)
- 🐦 [Twitter](https://twitter.com/) (coming soon)
- 🌐 [mood8.app](https://mood8.app)

## 📄 License

Proprietary. © 2026 Mood8. All rights reserved.

Source code will be open-sourced after public launch under MIT license.

---

<div align="center">

### Made with 💜 to help people become more of themselves

[Try Mood8 →](https://mood8.app)

</div>
