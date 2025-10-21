# 🧠 Brainiax: Logic & Word Puzzles PRD
**Namespace:** `com.brainiax.puzzles`
**Repo Type:** Flutter Monorepo (managed via Melos)
**Status:** ✅ Phase 0 – Environment & Scaffolding Complete

---

## 🎯 Goal
Build a cross-platform mobile puzzle app (Android + iOS) in Flutter that offers a variety of number and word puzzles with smooth performance, a polished UX, and minimal hosting costs.

The app should support:
- Daily challenges
- Streaks and player stats
- Ads-based monetization
- Leaderboards

**Constraints:**
- Must perform smoothly even on low-end devices
- Multiplayer and anti-cheat systems are out of scope for V1
- Android first, iOS port post feature-complete

---

## 🧩 Core Goals
- Deliver a polished, performant puzzle experience
- Offer daily challenges, streak tracking, offline play, and player stats
- Monetize via ads (banner + rewarded), with optional ad-free pass post-V1
- Use Firebase for lightweight backend sync and analytics
- Maintain clean modular architecture via Melos

---

## ⚙️ Tech Stack & Versions

### Frontend
- **Framework:** Flutter (Dart)
- **Flutter SDK:** 3.35.5 (Stable)
- **Dart SDK:** 3.9.2
- **Performance Target:** 60fps on low-end Android devices (even on 10k+ cell grids)

### Core Logic
- **Puzzle Engine:** `puzzle_core` Dart package
  - Handles generators, solvers, validators, and difficulty scoring logic

### Backend
- **Primary:** Firebase
  - Auth, Firestore, Remote Config, Crashlytics, Analytics
- **Future Consideration:** Supabase (for modularity/migration flexibility)
- **Firebase CLI:** Latest stable version
- **Config:** Separate `google-services.json` per environment (dev, staging, prod)

### Build & Configuration
- **Gradle:** Kotlin DSL (`build.gradle.kts`) with `productFlavors`
- **Android SDK:**
  - `minSdkVersion = flutter.minSdkVersion`
  - `targetSdkVersion = flutter.targetSdkVersion`

### Development & Tooling
- **DevTools:** 2.48.0
- **Melos:** 7.1.1 (monorepo management)

### CI/CD
- **Pipeline:** GitHub Actions → Google Play / TestFlight release
- **Status:** Configured and validated ✅ (completed during Phase 0)

---

## 🔥 Firebase & Environment Setup

Multi-environment configuration with distinct Firebase projects and Android flavors:

| Environment | Firebase Project Name    | Package Name                 |
|-------------|--------------------------|------------------------------|
| dev         | brainiax-puzzles-dev     | com.brainiax.puzzles.dev     |
| staging     | brainiax-puzzles-staging | com.brainiax.puzzles.staging |
| prod        | brainiax-puzzles         | com.brainiax.puzzles         |

**Configuration Highlights:**
- Implemented `productFlavors` in `build.gradle.kts` for all environments
- Dedicated `google-services.json` per flavor under `/android/app/src/<flavor>/`
- CI/CD supports environment-based builds (dev → staging → prod)

**Firebase Services:**
- Auth (Anonymous + Google/Apple planned)
- Firestore (user stats, streaks, leaderboards)
- Remote Config (ad frequency, interstitial timing)
- Crashlytics & Analytics

---

## 📦 Monorepo Architecture (Melos Managed)

**Structure:**

    root/

    ├─ apps/

        └─ app/ # Main Flutter application

    ├─ packages/

        ├─ puzzle_core/ # Core puzzle logic (generators, solvers, validators)

        └─ assets/ # Shared word lists, icons, puzzle templates


---

## 🧠 Core Puzzle Roster (V1)

### Number/Logic Puzzles
- Sudoku
- Kakuro
- Nonogram (black & white)
- Mathdoku (safe alt name for KenKen)
- Futoshiki
- Slitherlink
- Takuzu (Binary Puzzle)

### Word Puzzles
- Crossword (mini)
- Word Search
- Anagram Scramble
- Cryptogram
- Word Ladder

> ⚠️ *Wordle excluded due to IP concerns.*

---

## 🎮 Game Design Features

- **Daily Challenges:** Seed-based, deterministic per day/type
- **Random Play Mode:** Unique puzzles per user/session via random seeds
- **Streaks:** Global and per-puzzle type
- **Leaderboards:** Weekly by puzzle type (best/fastest times)
- **Player Stats:** Best times, puzzles completed, hint usage
- **Offline Play:** Offline-first, online-enhanced
- **Accessibility:** Large fonts, high contrast, haptics, color-blind-safe themes

---

## 💰 Monetization

- **Banner Ads:** Non-intrusive, no overlap with puzzle grids
- **Rewarded Ads:** For hints and streak savers (1 free hint per puzzle)
- **Interstitial Ads:** Optional, frequency controlled via Remote Config
- **IAP (Ad-Free Pass):** Deferred until post-V1

---

## 🌐 Hosting Philosophy

Keep hosting costs minimal:

- All puzzle generation runs on-device
- Daily challenges use deterministic seeds
- Random play uses local random seeds per user/session
- Backend syncs only metadata (runs, streaks, stats) to Firestore
- Boards and solves remain local
- Assets bundled in-app (no CDN fetches)
- Default anonymous auth, optional Google/Apple upgrade

---

## 🔐 Auth & Cloud Sync

- Default **anonymous login**
- Optional upgrade to **Google/Apple** (Phase 4)
- Syncs stats, streaks, and leaderboards via Firestore
- Offline-first, automatic sync when online
- Prompt users to sign in after 3–5 puzzles or streak milestones
- Use `linkWithCredential()` to merge anonymous and signed-in data

---

## 🧩 Development Style & Best Practices

### Architecture & State Management
- **State Management:** Riverpod 3.0.2
- **Routing:** go_router 16.2.4
- **Logic Separation:** Puzzle logic decoupled via `puzzle_core`
- **Performance:** Target 60fps using efficient `CustomPainter` rendering

### Development Workflow
- Use **Cursor** for Flutter boilerplate (UI, solvers, templates)
- **Test-Driven Development:**
  - Focus on puzzle generation, solving, and validation
  - Unit/integration tests mandatory for logic layers

### Code Quality
- Shared `analysis_options.yaml` for linting and best practices
- Code reviews required for all merges
- Performance profiling mandatory pre-release

### CI/CD & Branching
- **Automation:** GitHub Actions for build/test/deploy
- **Branch Strategy:**
  - `main` → Production (Firebase Prod)
  - `staging` → Pre-release testing (Firebase Staging)
  - `dev` → Active development (Firebase Dev)

---
