# Brainiax Puzzles — Figma Product Overrides

_Implementation reference for applying Figma designs to the Flutter app_

## Purpose

This document captures the product decisions that override the raw Figma output while implementing the approved screens in the Brainiax Puzzles Flutter app.

Use Figma as visual direction. Use the current Flutter app architecture as the source of truth for behavior, routing, state, persistence, daily challenge rules, completion records, and puzzle engines.

## Global implementation rules

- Do not paste Figma-generated code into production Flutter code.
- Do not replace existing Riverpod providers, go_router routes, active-run persistence, daily lockout, completion records, favourites, puzzle renderers, or engine flows.
- Implement one screen at a time.
- Product decisions in this document override Figma whenever they conflict.
- Keep UI work separate from puzzle engine, generation, solver, and progression logic.
- Do not fake metrics such as rank, attempts today, or social proof unless backed by real app data.
- Hide unfinished/deferred surfaces instead of showing broken placeholders.
- Preserve offline-first behavior.

## Bottom navigation and app shell

Final bottom navigation tabs:
- Home
- Daily
- Puzzles
- Profile

Overrides:
- Remove Settings from the bottom navigation.
- Settings remains accessible from the Home top-right icon and/or Profile.
- Play screen should not show bottom navigation.
- Secondary screens such as Settings, Tutorials, and Puzzle Detail overlays should not become primary bottom tabs.

## Home dashboard overrides

| Area | Product override |
|---|---|
| Header | Keep app identity/Brainiax branding. Keep daily streak indicator. Keep Settings icon. |
| Offline ready pill | Remove entirely from Home. |
| Today’s Challenge card | Keep. Use UTC reset countdown such as ‘Resets in 8h 42m’ or ‘Next puzzle in 8h 42m’. Countdown is more important than date display. |
| Daily streak | Show Daily Challenge streak only. Random play must not affect streak. |
| Continue card | Keep only when an unfinished active run exists. Show puzzle type, mode, difficulty, elapsed time, and progress. Resume must preserve mode/difficulty/elapsed state. |
| Quick Play | Keep Random/Surprise Me and Favourite Puzzle. Remove Browse All. |
| Stats preview | Show Total Solved, Today Completed, Completed This Week. Remove Hints Used from Home. |
| Word Logic / word puzzles | Do not show in V1 UI until word puzzles are implemented. |
| Completed daily | Home daily CTA must not restart a completed daily puzzle. |

## Daily Hub overrides

| Area | Product override |
|---|---|
| Header | Keep ‘Daily Challenges’. Date may be shown, but reset countdown is more important. |
| Top-right streak | Keep fire-streak treatment such as ‘🔥 13 day streak’. |
| UTC reset | Use global UTC daily reset. Copy should usually say ‘Resets in …’ or ‘Next set in …’. |
| Weekly calendar | Keep. Completed = at least one daily puzzle completed that UTC day. Completed green/check, missed red/cross, today incomplete outlined, future muted. |
| Dynamic streak/status card | Keep. Copy changes by state: start streak, keep streak alive, streak secured, daily set complete. |
| Puzzle-name tabs | Remove. Do not use horizontal puzzle-name tabs as the primary filter. |
| Filters | Use All, Unplayed, Completed. Leaderboard eligible is deferred. |
| Today’s Puzzles | Keep. Show progress count like 2/5 done. Cards show Play, Resume, or Completed. |
| Ranks/social proof | Hide unless backed by real leaderboard/attempt data. Do not fake ‘x playing’ or rank. |
| Locked streaks | Remove from puzzle cards. |
| Offline note | Use subtle copy: ‘Today’s set stays playable offline once opened.’ |
| Completed daily | Completed daily puzzle must not start a fresh timed/scored attempt. |

## Puzzle Library overrides

| Area | Product override |
|---|---|
| Screen purpose | Choose puzzle type only. |
| Search | Remove. |
| Filters | Use All, Numbers, Visual, Favourites. Hide Word until word puzzles exist. |
| Categories | Numbers: Sudoku, MathDoku. Visual: Slitherlink, Killer Queens/Queens, Nonogram. |
| Difficulty display | Show available difficulties as chips/labels only: Easy, Medium, Hard, Expert as applicable. |
| Difficulty selection | Do not select difficulty directly on the card. Difficulty selection happens in Puzzle Detail picker. |
| Favourite | Keep star/favourite button on card. Tapping star toggles favourite without opening detail picker. |
| Card tap | Tap card body opens Puzzle Detail modal bottom sheet. |
| In-progress | Show In Progress badge if unfinished active run exists. |
| Best stats | Do not add best time/solved count to library cards for now. |
| Descriptions | Keep concise puzzle descriptions. |

## Puzzle Detail picker overrides

| Area | Product override |
|---|---|
| Navigation form | Use modal bottom sheet / overlay, not full screen. |
| Header | Keep puzzle icon and puzzle name. Use star favourite button, not bookmark. |
| Objective | Keep concise objective box. This is not the full tutorial. |
| How to Play | Add/keep How to Play entry. It may open placeholder tutorial if full content is not ready. |
| Mode cards | Keep Daily Challenge and Random Play side-by-side/selectable cards. |
| Daily copy | ‘Same puzzle for everyone’ plus reset countdown. |
| Random copy | ‘Infinite variety’ plus ‘Unique to you’. |
| Difficulty | Random mode: selectable difficulty chips. Daily mode: fixed/read-only daily difficulty. |
| Grid selector | Remove entirely. Grid/size is internal and tied to puzzle type/difficulty. |
| Saved Game card | Show only when active run exists. Include mode, difficulty, elapsed time, progress, and Resume CTA. No notes text. |
| Main CTA | Label changes based on selected mode: Start Daily Challenge / Start Random Puzzle. Disabled or changed if daily completed. |
| Info icon row | Remove Offline / Daily seed / Best time row. |
| Completed daily | Show Completed Today / View Solved Puzzle behavior. Do not start a fresh timed/scored daily attempt. |

## Play screen / solver-screen shared overrides

| Area | Product override |
|---|---|
| Source of truth | Preserve existing puzzle renderers, game state provider, move semantics, active run persistence, and completion flow. |
| Timer | Timer starts only after board is loaded and visible. Daily unfinished timer resumes after app restart. Completed daily view should not run timer. |
| Difficulty display | Use actual generated/current game difficulty. Never default completion or play header to Hard unless generated puzzle is Hard. |
| Move counter | Undo increments move count. No-op clear does not increment. Helper marks should not be over-counted. |
| Notes | Clear removes notes in note-capable puzzles. Filled values should clean relevant peer notes where implemented. |
| Hints | Hide/disable hints for unsupported engines. Do not show enabled button that only says ‘Hint not available’. |
| Tutorial | How to Play entry should be available from play screen. |
| Completion popup | Show puzzle name/type, mode, actual difficulty, elapsed time, moves, and hints used if nonzero. |

## Profile overrides

| Area | Product override |
|---|---|
| Scope | Local-only profile/stats polish for now. Do not implement cloud sync in this UI phase. |
| Stats | Show current daily streak, best streak if available, total solved, today completed, completed this week, and per-puzzle stats if available. |
| Settings | Settings entry should be accessible from Profile. |
| Account/cloud | Do not show broken account/sync UI until Phase 4/cloud work exists. Use subtle ‘coming later’ only if necessary. |

## Settings overrides

| Area | Product override |
|---|---|
| Access | Settings is not a bottom tab. Access via Home/Profile. |
| Scope | Keep simple. Do not over-design before account/cloud/ads settings exist. |
| Useful current items | Theme/app appearance, privacy policy, feedback/about, benchmark/dev access if hidden behind debug gesture. |
| Deferred items | Ads preferences, cloud sync, account upgrade, leaderboard settings. |

## Shared states and edge cases

| Area | Product override |
|---|---|
| Loading | Show clear loading/generation state. Timer should not run before board is playable. |
| Generation failure | Show friendly error and Retry/Back options. No blank board. |
| No active run | Hide Continue card or show appropriate empty state, not fake content. |
| No favourites | Favourite Puzzle quick play should route to Puzzles or show useful empty state. |
| All daily completed | Show Daily set complete and next reset countdown. Do not offer fresh daily restart. |
| Completed daily view | Show solved board/stats or disabled replay with timer --:--; do not count attempt. |

## Suggested UI implementation order

1. Shared UI components: cards, chips, section headers, stat tiles, empty states.
2. Home dashboard.
3. Puzzle Library.
4. Puzzle Detail bottom sheet.
5. Daily Hub polish.
6. Profile local stats polish.
7. Settings polish only where needed.
8. Final visual QA pass.

## Standard Codex instruction block

Use this block at the top of every Figma UI implementation prompt:

```text
Read docs/ui_figma_product_overrides.md first.
Use Figma as visual reference only.
Product overrides in that document take precedence over Figma.
Do not paste Figma-generated code into production.
Implement native Flutter UI using the existing app architecture.
Preserve Riverpod providers, go_router routes, active run persistence, daily lockout, completion records, favourites, puzzle renderers, and engine flows.
Do not modify puzzle generation, solver logic, completion metadata, or daily lifecycle unless explicitly asked.
Run flutter analyze and relevant tests.
```
