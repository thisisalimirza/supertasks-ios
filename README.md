# Supertasks for iPad

A native SwiftUI/SwiftData port of [Supertasks](https://github.com/thisisalimirza/supertasks) (the Mac app), built for iPadOS. Same Superhuman-inspired, keyboard-first task manager — Inbox/Today/Tomorrow/Week/Upcoming/All/Done views, Projects, Splits (smart filters), a `⌘K` command palette, and dense `j`/`k`-style navigation — rebuilt from scratch as a first-class iPad app instead of wrapping the Electron/React app in a webview.

## Requirements

- Xcode 16 or later (the project uses Xcode 16's "file-system-synchronized group" format, so file references don't need to be manually maintained in the `.xcodeproj`)
- iPadOS 17.0+ deployment target
- iPad only (`TARGETED_DEVICE_FAMILY = 2`) — this is not a Universal app

## Building

1. Open `Supertasks.xcodeproj` in Xcode.
2. Select your development team under the target's Signing & Capabilities (the project ships with automatic signing and no team set).
3. Build and run on an iPad Simulator or a physical iPad.

**This project was written without access to a Mac/Xcode — it has never been compiled.** If the build fails, please share the error output; most likely candidates are a SwiftUI API that shifted between OS versions or a small typo. Everything else (data model, business logic, layout, keyboard handling) was ported carefully from the Mac app's source.

## Architecture

- **Persistence**: SwiftData (`TaskItem`, `Project`, `Split` `@Model` classes), local-only — no sync with the Mac app (yet).
- **State**: `AppStore` (`Store/AppStore.swift`) is a near 1:1 port of the Mac app's Zustand store (`taskStore.ts`) — same view-filtering logic, undo stack, toasts, selection model, split-rule filter engine.
- **Keyboard shortcuts**: `Keyboard/KeyboardShortcuts.swift` ports the Mac app's `useKeyboard.ts` almost line for line, via a root-level `.onKeyPress` handler. Every hardware-keyboard shortcut from the Mac app works here too (`j`/`k` navigation, `g`-chords, `⌘K`, `⌘Z`, etc).
- **Touch**: swipe actions (complete/delete), long-press context menus, drag-and-drop reordering, and a floating add button are all new — the Mac app is mouse/keyboard only, so these were added to make the app feel native on iPad.
- **Theme**: `Design/Theme.swift` is an exact hex-for-hex port of the Mac app's `global.css` custom properties, kept as an explicit in-app light/dark toggle (not tied to system appearance), matching the Mac app.

## Known gaps vs. the Mac app (intentionally out of scope for this pass)

- **Quick Add** (global hotkey capture window) — no direct iPad equivalent; could become a Share Extension, Siri Shortcut, or Home Screen Quick Action later.
- **"What's New" changelog modal** — no version history to show yet on a fresh app.
- **iCloud/CloudKit sync** — standalone/local-only for now, by design (see the plan this was built from).
- **iPhone support** — iPad-only, by design.
