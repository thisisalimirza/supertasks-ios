import SwiftUI

extension Notification.Name {
    /// Posted when Tab should move focus into the detail panel's notes editor —
    /// mirrors the `supertasks:focus-notes` window event in the Mac app.
    static let supertasksFocusNotes = Notification.Name("supertasksFocusNotes")
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ShortcutDef: Identifiable {
    let id = UUID()
    let keyLabel: String
    let description: String
    let group: String
}

/// Single source of truth for the shortcuts shown in the cheatsheet and the command
/// palette's "Actions" group. Matches the `shortcuts` array in the Mac app's
/// useKeyboard.ts (g-chords and `!` are intentionally left out there too — advanced/
/// power-user shortcuts not surfaced in the discoverability UI).
enum ShortcutCatalog {
    static let all: [ShortcutDef] = [
        ShortcutDef(keyLabel: "⌘K", description: "Open command palette", group: "Global"),
        ShortcutDef(keyLabel: "⌘/", description: "Show keyboard shortcuts", group: "Global"),
        ShortcutDef(keyLabel: "/", description: "Open settings", group: "Global"),
        ShortcutDef(keyLabel: "⌘⇧L", description: "Toggle light / dark mode", group: "Global"),
        ShortcutDef(keyLabel: "J", description: "Move down", group: "Navigation"),
        ShortcutDef(keyLabel: "K", description: "Move up", group: "Navigation"),
        ShortcutDef(keyLabel: "Esc", description: "Close / go back", group: "Navigation"),
        ShortcutDef(keyLabel: "↵", description: "Open selected task", group: "Navigation"),
        ShortcutDef(keyLabel: "C", description: "Create new task", group: "Tasks"),
        ShortcutDef(keyLabel: "E", description: "Edit selected task title", group: "Tasks"),
        ShortcutDef(keyLabel: "D", description: "Toggle done", group: "Tasks"),
        ShortcutDef(keyLabel: "S", description: "Star / priority flag", group: "Tasks"),
        ShortcutDef(keyLabel: "R", description: "Set due date", group: "Tasks"),
        ShortcutDef(keyLabel: "H", description: "Hold until (start date)", group: "Tasks"),
        ShortcutDef(keyLabel: "L", description: "Edit labels", group: "Tasks"),
        ShortcutDef(keyLabel: "M", description: "Assign project", group: "Tasks"),
        ShortcutDef(keyLabel: "Tab", description: "Focus notes (in detail)", group: "Tasks"),
        ShortcutDef(keyLabel: "⌘Z", description: "Undo last action", group: "Global"),
        ShortcutDef(keyLabel: "X", description: "Select task (bulk)", group: "Tasks"),
        ShortcutDef(keyLabel: "⌫", description: "Delete task", group: "Tasks"),
        ShortcutDef(keyLabel: "⌘D", description: "Mark all selected done", group: "Bulk"),
        ShortcutDef(keyLabel: "⌘⌫", description: "Delete all selected", group: "Bulk"),
    ]
}

/// Holds the mutable "g" chord state (armed + 1s reset timer) across key presses.
/// A plain class kept in `@State` so its identity — not its contents — drives view updates.
final class ChordState {
    private var armed = false
    private var resetTask: Task<Void, Never>?

    func arm() {
        armed = true
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
            self.armed = false
        }
    }

    /// Returns whether the chord was armed, and disarms it.
    func consume() -> Bool {
        defer { armed = false; resetTask?.cancel() }
        return armed
    }
}

/// Root-level hardware-keyboard handler. A near 1:1 port of the big switch statement in
/// useKeyboard.ts. Gated by `store.isTextInputFocused` (the Swift equivalent of the JS
/// `isInput` check) so plain letter shortcuts don't fire while the user is typing.
@MainActor
func handleGlobalKeyPress(_ press: KeyPress, store: AppStore, chord: ChordState) -> KeyPress.Result {
    let cmd = press.modifiers.contains(.command)
    let shift = press.modifiers.contains(.shift)
    let isInput = store.isTextInputFocused
    let chars = press.characters.lowercased()

    func selectedID() -> UUID? { store.getVisibleTasks()[safe: store.selectedIndex]?.id }
    func selectedTask() -> TaskItem? {
        guard let id = selectedID() else { return nil }
        return store.tasks.first { $0.id == id }
    }

    // ── Escape: always fires, even while typing ────────────────────────────
    if press.key == .escape && !cmd {
        if store.isCommandPaletteOpen { store.isCommandPaletteOpen = false; return .handled }
        if store.isShortcutCheatsheetOpen { store.isShortcutCheatsheetOpen = false; return .handled }
        if store.isProjectNavOpen { store.isProjectNavOpen = false; return .handled }
        if store.isSplitEditorOpen { store.isSplitEditorOpen = false; return .handled }
        if store.isSettingsOpen { store.setSettingsOpen(false); return .handled }
        if store.isNewProjectOpen { store.isNewProjectOpen = false; return .handled }
        if store.activePicker != nil { store.closePicker(); return .handled }
        if store.editingTaskID != nil { store.editingTaskID = nil; return .handled }
        if store.isCreating { store.cancelCreating(); return .handled }
        if store.isDetailOpen { store.closeDetail(); return .handled }
        if !store.selectedTaskIDs.isEmpty { store.clearSelection(); return .handled }
        return .ignored
    }

    // "/" without a modifier toggles Settings — must run before the input blocker.
    if chars == "/" && !cmd && !isInput {
        store.setSettingsOpen(!store.isSettingsOpen)
        return .handled
    }

    // Overlays own the keyboard while open.
    if store.isCommandPaletteOpen || store.isShortcutCheatsheetOpen || store.isProjectNavOpen
        || store.isSplitEditorOpen || store.isSettingsOpen {
        return .ignored
    }
    if store.activePicker != nil { return .ignored }

    // ── "g" chord ────────────────────────────────────────────────────────
    if !isInput && chars == "g" && !cmd {
        chord.arm()
        return .handled
    }
    if !isInput && chord.consume() {
        switch chars {
        case "i": store.setView(.inbox); return .handled
        case "a": store.setView(.all); return .handled
        case "d": store.setView(.done); return .handled
        case "t": store.setView(.today); return .handled
        case "n": store.setView(.tomorrow); return .handled
        case "w": store.setView(.week); return .handled
        case "p": store.isProjectNavOpen = true; return .handled
        default:
            if let num = Int(chars), (1...9).contains(num) {
                let enabled = store.splits.filter(\.enabled).sorted { $0.sortOrder < $1.sortOrder }
                if let target = enabled[safe: num - 1] { store.setActiveSplit(target.id) }
                return .handled
            }
        }
    }

    // ── Undo ─────────────────────────────────────────────────────────────
    if cmd && !shift && chars == "z" && !isInput {
        store.undo(); return .handled
    }

    // ── Global ───────────────────────────────────────────────────────────
    if cmd && chars == "k" { store.isCommandPaletteOpen = true; return .handled }
    if cmd && chars == "/" { store.isShortcutCheatsheetOpen = true; return .handled }
    if cmd && shift && chars == "l" { store.toggleTheme(); return .handled }

    if press.key == .leftArrow && !cmd && store.isDetailOpen && !isInput {
        store.closeDetail(); return .handled
    }

    // These two fire even while the title/notes text field is focused, matching
    // TaskDetail.tsx's own (ungated) keydown listener.
    if cmd && press.key == .return && store.isDetailOpen {
        store.closeDetail(); return .handled
    }
    if cmd && shift && chars == "," && store.isDetailOpen {
        if let task = selectedTask() { store.cyclePriority(task) }
        return .handled
    }

    if isInput { return .ignored }

    // ── Enter — open detail ─────────────────────────────────────────────
    if press.key == .return && !cmd {
        if let id = selectedID() { store.openDetail(id) }
        return .handled
    }

    // ── Tab — cycle tabs, or focus notes when detail is open ────────────
    if press.key == .tab && !cmd {
        if store.isDetailOpen {
            NotificationCenter.default.post(name: .supertasksFocusNotes, object: nil)
        } else {
            store.navigateTabRelative(shift ? -1 : 1)
        }
        return .handled
    }

    // ── Cmd+J / Cmd+K / Cmd+Arrow — reorder ─────────────────────────────
    if cmd && !shift && (chars == "j" || press.key == .downArrow) {
        let visible = store.getVisibleTasks()
        let id = !store.selectedTaskIDs.isEmpty
            ? visible.first { store.selectedTaskIDs.contains($0.id) }?.id
            : visible[safe: store.selectedIndex]?.id
        if let id { store.reorderTask(id: id, dir: 1) }
        return .handled
    }
    if cmd && !shift && (chars == "k" || press.key == .upArrow) {
        let visible = store.getVisibleTasks()
        let id = !store.selectedTaskIDs.isEmpty
            ? visible.first { store.selectedTaskIDs.contains($0.id) }?.id
            : visible[safe: store.selectedIndex]?.id
        if let id { store.reorderTask(id: id, dir: -1) }
        return .handled
    }

    // ── Shift+J / Shift+K / Shift+Arrow — extend selection ──────────────
    if shift && !cmd && (chars == "j" || press.key == .downArrow) { store.extendSelection(1); return .handled }
    if shift && !cmd && (chars == "k" || press.key == .upArrow) { store.extendSelection(-1); return .handled }

    // ── J / K / Arrow navigation ─────────────────────────────────────────
    if chars == "j" || press.key == .downArrow { store.moveSelection(1); return .handled }
    if chars == "k" || press.key == .upArrow { store.moveSelection(-1); return .handled }

    // ── Arrow Right / Left — open / close detail ─────────────────────────
    if press.key == .rightArrow && !cmd {
        if let id = selectedID(), !store.isDetailOpen { store.openDetail(id) }
        return .handled
    }
    if press.key == .leftArrow && !cmd {
        if store.isDetailOpen { store.closeDetail() }
        return .handled
    }

    // ── Task actions ─────────────────────────────────────────────────────
    if chars == "c" {
        if !store.isDetailOpen { store.beginCreating() }
        return .handled
    }
    if chars == "e" {
        if let id = selectedID(), !store.isDetailOpen { store.editingTaskID = id }
        return .handled
    }
    if chars == "d" && !cmd {
        if let task = selectedTask() { store.toggleDone(task) }
        return .handled
    }
    if chars == "s" {
        if let task = selectedTask() { store.toggleStar(task) }
        return .handled
    }
    if chars == "!" {
        if !store.selectedTaskIDs.isEmpty {
            for id in store.selectedTaskIDs {
                if let task = store.tasks.first(where: { $0.id == id }) { store.cyclePriority(task) }
            }
        } else if let task = selectedTask() {
            store.cyclePriority(task)
        }
        return .handled
    }
    if chars == "r" {
        if let id = selectedID() { store.setActivePicker(.due, taskID: id) }
        return .handled
    }
    if chars == "h" {
        if let id = selectedID() { store.setActivePicker(.startDate, taskID: id) }
        return .handled
    }
    if chars == "l" && !cmd {
        if let id = selectedID() { store.setActivePicker(.label, taskID: id) }
        return .handled
    }
    if chars == "m" {
        if let id = selectedID() { store.setActivePicker(.project, taskID: id) }
        return .handled
    }
    if chars == "x" {
        if let id = selectedID() { store.toggleSelectTask(id) }
        return .handled
    }
    // Backspace / Delete — delete selection (bulk if multi-selected, else single)
    if press.key == .delete && !cmd {
        if !store.selectedTaskIDs.isEmpty {
            store.deleteBulkTasks(store.selectedTaskIDs)
            store.clearSelection()
        } else if let task = selectedTask() {
            store.deleteTask(task)
        }
        return .handled
    }

    // ── Bulk actions ─────────────────────────────────────────────────────
    if cmd && chars == "d" {
        if !store.selectedTaskIDs.isEmpty {
            for id in store.selectedTaskIDs {
                if let task = store.tasks.first(where: { $0.id == id }) { store.toggleDone(task) }
            }
            store.clearSelection()
        }
        return .handled
    }
    if cmd && press.key == .delete {
        if !store.selectedTaskIDs.isEmpty { store.deleteBulkTasks(store.selectedTaskIDs) }
        return .handled
    }

    return .ignored
}

/// Attach to any TextField/TextEditor's `@FocusState` bool so AppStore.isTextInputFocused
/// stays accurate (the Swift equivalent of checking `document.activeElement` in the JS app).
extension View {
    func reportsTextFocus(_ isFocused: Bool, to store: AppStore) -> some View {
        onChange(of: isFocused) { _, newValue in
            store.isTextInputFocused = newValue
        }
    }
}
