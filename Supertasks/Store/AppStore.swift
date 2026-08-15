import Foundation
import SwiftUI
import SwiftData

struct UndoEntry: Identifiable {
    let id: UUID
    let description: String
    let perform: () -> Void
}

struct Toast: Identifiable, Equatable {
    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    let id: UUID
    let message: String
    var undoID: UUID?
}

/// A tab in the header row: either a built-in view or a user-defined split.
enum TabEntry: Hashable {
    case builtin(TaskViewKind)
    case split(UUID)
}

/// The single source of truth for the app. A near 1:1 port of the Mac app's taskStore.ts
/// (Zustand store), adapted to SwiftData for persistence. `tasks`/`projects`/`splits` hold
/// live SwiftData model references — mutating a field on one of them and calling `save()`
/// persists it directly, mirroring the Mac app's optimistic-update-then-persist pattern.
@MainActor
final class AppStore: ObservableObject {
    let context: ModelContext

    // MARK: Data
    @Published var tasks: [TaskItem] = []
    @Published var projects: [Project] = []
    @Published var splits: [Split] = []

    // MARK: Selection
    @Published var selectedIndex: Int = 0
    @Published var selectedTaskID: UUID?
    @Published var selectedTaskIDs: Set<UUID> = []
    @Published var selectionAnchor: Int?

    // MARK: Navigation
    @Published var activeView: TaskViewKind = .inbox
    @Published var activeSplitID: UUID?
    @Published var selectedProject: String?
    @Published var showCompletedInView: Bool = false

    // MARK: Overlay / panel visibility
    @Published var isDetailOpen: Bool = false
    @Published var isCommandPaletteOpen: Bool = false
    @Published var isShortcutCheatsheetOpen: Bool = false
    @Published var isProjectNavOpen: Bool = false
    @Published var isSplitEditorOpen: Bool = false
    @Published var editingSplitID: UUID?
    @Published var splitEditorIntent: SplitEditorIntent = .split
    @Published var isNewProjectOpen: Bool = false
    @Published var isSettingsOpen: Bool = false
    @Published var settingsSection: SettingsSection?

    // MARK: Editing state
    @Published var isCreating: Bool = false
    @Published var editingTaskID: UUID?
    @Published var completingTaskID: UUID?
    private var creationSavedIndex: Int?

    // MARK: Pickers
    @Published var activePicker: PickerKind?
    @Published var pickerTaskID: UUID?

    /// True while any TextField/TextEditor in the app has focus — the Swift equivalent of
    /// checking `document.activeElement.tagName` in the Mac app's key handler. Kept up to
    /// date via `.reportsTextFocus(_:to:)` on every text input.
    @Published var isTextInputFocused: Bool = false

    // MARK: Undo / toast
    @Published var undoStack: [UndoEntry] = []
    @Published var toasts: [Toast] = []

    // MARK: Settings (persisted)
    // NB: deliberately NOT @AppStorage — that property wrapper only publishes view-invalidation
    // through SwiftUI's own DynamicProperty machinery, which only fires when the wrapper is
    // declared directly on a View. Declared on a plain ObservableObject class like this one, it
    // would silently fail to trigger `objectWillChange`, so views wouldn't re-render on change.
    // @Published + manual UserDefaults read/write gets persistence AND correct observation.
    @Published var theme: AppTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "supertasksTheme") ?? "") ?? .light {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "supertasksTheme") }
    }
    @Published var commandPaletteGroupHeaders: Bool = UserDefaults.standard.bool(forKey: "supertasksCmdHeaders") {
        didSet { UserDefaults.standard.set(commandPaletteGroupHeaders, forKey: "supertasksCmdHeaders") }
    }
    @Published var onboardingCompleted: Bool = UserDefaults.standard.bool(forKey: "supertasksOnboardingCompleted") {
        didSet { UserDefaults.standard.set(onboardingCompleted, forKey: "supertasksOnboardingCompleted") }
    }
    @Published var recentCommandIDs: [String] = UserDefaults.standard.stringArray(forKey: "supertasksRecentCmds") ?? [] {
        didSet { UserDefaults.standard.set(recentCommandIDs, forKey: "supertasksRecentCmds") }
    }

    var colors: ThemeColors { ThemeColors.resolve(theme) }

    private static let builtinTabs: [TaskViewKind] = [.inbox, .today, .upcoming, .all, .done]

    init(context: ModelContext) {
        self.context = context
        loadTasks()
    }

    private func save() {
        try? context.save()
    }

    // MARK: - Load

    func loadTasks() {
        tasks = (try? context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        splits = (try? context.fetch(FetchDescriptor<Split>())) ?? []

        // Backfill: create a split for any project that doesn't have one covering it yet.
        let coveredProjects = Set(splits.flatMap(\.rules.projects))
        let allProjectNames = Set(tasks.compactMap { $0.project.isEmpty ? nil : $0.project })
        let missing = allProjectNames.subtracting(coveredProjects).sorted()
        guard !missing.isEmpty else { return }
        var maxOrder = splits.map(\.sortOrder).max() ?? -1
        for name in missing {
            maxOrder += 1
            let split = Split(
                name: name,
                rules: SplitRules(projects: [name]),
                ruleOperator: .AND,
                enabled: true,
                sortOrder: maxOrder
            )
            context.insert(split)
            splits.append(split)
        }
        save()
    }

    // MARK: - Task CRUD

    @discardableResult
    func createTask(title: String, dueDate: Date? = nil, startDate: Date? = nil, project: String = "", status: TaskStatus = .inbox, labels: [String] = [], priority: TaskPriority = .none) -> TaskItem {
        let task = TaskItem(title: title, status: status, priority: priority, dueDate: dueDate, startDate: startDate, project: project, labels: labels)
        context.insert(task)
        tasks.insert(task, at: 0)
        save()
        return task
    }

    /// Direct-mutate a task's fields and persist. Swift's reference-type models make a
    /// generic "updates dictionary" (as in the JS store) unnecessary — callers just set
    /// the fields they want inside the closure.
    func mutate(_ task: TaskItem, _ body: (TaskItem) -> Void) {
        body(task)
        save()
    }

    func deleteTask(_ task: TaskItem) {
        let snapshot = TaskSnapshot(task)
        tasks.removeAll { $0.id == task.id }
        if selectedTaskID == task.id {
            selectedTaskID = nil
            isDetailOpen = false
        }
        selectedTaskIDs.remove(task.id)
        context.delete(task)
        save()

        let undoID = UUID()
        pushUndo(UndoEntry(id: undoID, description: "Delete") { [weak self] in
            guard let self else { return }
            let restored = snapshot.makeTask()
            self.context.insert(restored)
            self.tasks.insert(restored, at: 0)
            self.save()
        })
        addToast("\"\(String(task.title.prefix(28)))\" deleted", undoID: undoID)
    }

    func deleteBulkTasks(_ ids: Set<UUID>) {
        let victims = tasks.filter { ids.contains($0.id) }
        guard !victims.isEmpty else { return }
        let snapshots = victims.map(TaskSnapshot.init)
        tasks.removeAll { ids.contains($0.id) }
        selectedTaskIDs.removeAll()
        for v in victims { context.delete(v) }
        save()

        let undoID = UUID()
        pushUndo(UndoEntry(id: undoID, description: "Bulk delete") { [weak self] in
            guard let self else { return }
            let restored = snapshots.map { $0.makeTask() }
            restored.forEach { self.context.insert($0) }
            self.tasks.insert(contentsOf: restored, at: 0)
            self.save()
        })
        addToast("\(ids.count) tasks deleted", undoID: undoID)
    }

    func toggleDone(_ task: TaskItem) {
        let wasDone = task.status == .done
        let prevStatus = task.status
        let prevCompletedAt = task.completedAt

        func apply() {
            task.status = wasDone ? .inbox : .done
            task.completedAt = wasDone ? nil : .now
            save()
            let undoID = UUID()
            pushUndo(UndoEntry(id: undoID, description: wasDone ? "Reopen" : "Done") { [weak self] in
                task.status = prevStatus
                task.completedAt = prevCompletedAt
                self?.save()
            })
        }

        if wasDone {
            apply()
        } else {
            // Slide-away animation before the task actually leaves the visible list.
            completingTaskID = task.id
            Task { @MainActor [weak self] in
                try? await _Concurrency.Task.sleep(nanoseconds: 280_000_000)
                self?.completingTaskID = nil
                apply()
            }
        }
    }

    func toggleStar(_ task: TaskItem) {
        let prev = task.starred
        task.starred.toggle()
        save()
        let undoID = UUID()
        pushUndo(UndoEntry(id: undoID, description: prev ? "Unstar" : "Star") { [weak self] in
            task.starred = prev
            self?.save()
        })
    }

    func cyclePriority(_ task: TaskItem) {
        let prev = task.priority
        task.priority = prev.next
        save()
        let undoID = UUID()
        pushUndo(UndoEntry(id: undoID, description: "Priority") { [weak self] in
            task.priority = prev
            self?.save()
        })
    }

    // MARK: - Reorder

    func reorderTask(id: UUID, dir: Int) {
        guard activeView != .upcoming, activeView != .done else { return }
        let visible = getVisibleTasks()

        let idsToMove: [UUID] = (!selectedTaskIDs.isEmpty && selectedTaskIDs.contains(id))
            ? visible.filter { selectedTaskIDs.contains($0.id) }.map(\.id)
            : [id]

        let groupIndices = idsToMove.compactMap { tid in visible.firstIndex { $0.id == tid } }.sorted()
        guard !groupIndices.isEmpty else { return }
        let from = groupIndices[0]
        let to = groupIndices[groupIndices.count - 1]
        if dir == 1 && to >= visible.count - 1 { return }
        if dir == -1 && from <= 0 { return }

        let pivotIdx = dir == 1 ? to + 1 : from - 1
        let segmentIndices = dir == 1 ? groupIndices + [pivotIdx] : [pivotIdx] + groupIndices
        let sortOrders = segmentIndices.map { visible[$0].sortOrder }
        let segTasks = segmentIndices.map { visible[$0] }
        let newOrder: [TaskItem] = dir == 1
            ? [segTasks.last!] + segTasks.dropLast()
            : Array(segTasks.dropFirst()) + [segTasks.first!]

        for (task, order) in zip(newOrder, sortOrders) { task.sortOrder = order }
        save()

        let newFrom = from + dir
        selectedIndex = newFrom
        if !selectedTaskIDs.isEmpty, let anchor = selectionAnchor {
            selectionAnchor = anchor + dir
        }
    }

    func moveTaskToPosition(sourceID: UUID, targetID: UUID) {
        guard activeView != .upcoming, activeView != .done else { return }
        let visible = getVisibleTasks()
        guard let sourceIdx = visible.firstIndex(where: { $0.id == sourceID }),
              let targetIdx = visible.firstIndex(where: { $0.id == targetID }),
              sourceIdx != targetIdx else { return }

        let sortOrders = visible.map(\.sortOrder).sorted(by: >)
        var withoutSource = visible.filter { $0.id != sourceID }
        let insertAt = targetIdx > sourceIdx ? targetIdx - 1 : targetIdx
        withoutSource.insert(visible[sourceIdx], at: insertAt)

        for (task, order) in zip(withoutSource, sortOrders) { task.sortOrder = order }
        save()
        selectedIndex = insertAt
    }

    // MARK: - Selection / navigation

    func setSelectedIndex(_ index: Int) {
        let visible = getVisibleTasks()
        let clamped = max(0, min(index, visible.count - 1))
        selectedIndex = clamped
        selectedTaskID = visible.indices.contains(clamped) ? visible[clamped].id : nil
    }

    func moveSelection(_ dir: Int) {
        selectionAnchor = nil
        setSelectedIndex(selectedIndex + dir)
    }

    func openDetail(_ id: UUID) {
        let visible = getVisibleTasks()
        let idx = visible.firstIndex { $0.id == id }
        selectedTaskID = id
        selectedIndex = idx ?? 0
        isDetailOpen = true
    }

    func closeDetail() { isDetailOpen = false }

    func setView(_ view: TaskViewKind) {
        activeView = view
        activeSplitID = nil
        selectedIndex = 0
        isDetailOpen = false
        selectedTaskIDs.removeAll()
        activePicker = nil
        pickerTaskID = nil
        showCompletedInView = false
        selectedTaskID = getVisibleTasks().first?.id
    }

    func toggleSelectTask(_ id: UUID) {
        if selectedTaskIDs.contains(id) { selectedTaskIDs.remove(id) } else { selectedTaskIDs.insert(id) }
    }

    func clearSelection() {
        selectedTaskIDs.removeAll()
        selectionAnchor = nil
    }

    func extendSelection(_ dir: Int) {
        let visible = getVisibleTasks()
        let anchor = selectionAnchor ?? selectedIndex
        let newIndex = max(0, min(visible.count - 1, selectedIndex + dir))
        guard newIndex != selectedIndex else { return }
        let lo = min(anchor, newIndex), hi = max(anchor, newIndex)
        selectedTaskIDs = Set(visible[lo...hi].map(\.id))
        selectedIndex = newIndex
        selectionAnchor = anchor
    }

    // MARK: - UI toggles

    func setActivePicker(_ type: PickerKind?, taskID: UUID? = nil) {
        activePicker = type
        pickerTaskID = taskID ?? selectedTaskID
    }

    func closePicker() {
        activePicker = nil
        pickerTaskID = nil
    }

    func toggleTheme() { theme = theme == .dark ? .light : .dark }

    /// Snapshots the current selection so `cancelCreating()` can restore it — makes `C` feel
    /// fully reversible, same as the Mac app's InlineTaskCreator.
    func beginCreating() {
        creationSavedIndex = selectedIndex
        isCreating = true
    }

    func cancelCreating() {
        isCreating = false
        if let saved = creationSavedIndex { setSelectedIndex(saved) }
        creationSavedIndex = nil
    }

    func finishCreating() {
        isCreating = false
        creationSavedIndex = nil
    }

    // MARK: - Undo / toast

    func pushUndo(_ entry: UndoEntry) {
        undoStack.insert(entry, at: 0)
        if undoStack.count > 20 { undoStack.removeLast(undoStack.count - 20) }
    }

    func undo() {
        guard let top = undoStack.first else { return }
        undoStack.removeFirst()
        toasts.removeAll { $0.undoID == top.id }
        top.perform()
        addToast("↩ \(top.description) undone")
    }

    func addToast(_ message: String, undoID: UUID? = nil) {
        toasts.append(Toast(id: UUID(), message: message, undoID: undoID))
        if toasts.count > 4 { toasts.removeFirst(toasts.count - 4) }
    }

    func dismissToast(_ id: UUID) {
        toasts.removeAll { $0.id == id }
    }

    func addRecentCommand(_ id: String) {
        var next = recentCommandIDs.filter { $0 != id }
        next.insert(id, at: 0)
        recentCommandIDs = Array(next.prefix(5))
    }

    // MARK: - Labels

    func getAllLabels() -> [String] {
        Array(Set(tasks.flatMap(\.labels))).sorted()
    }

    func toggleLabel(_ task: TaskItem, label: String) {
        if task.labels.contains(label) {
            task.labels.removeAll { $0 == label }
        } else {
            task.labels.append(label)
        }
        save()
    }

    func renameLabel(_ old: String, to new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != old else { return }
        for task in tasks where task.labels.contains(old) {
            task.labels = task.labels.map { $0 == old ? trimmed : $0 }
        }
        save()
    }

    func deleteLabel(_ name: String) {
        for task in tasks where task.labels.contains(name) {
            task.labels.removeAll { $0 == name }
        }
        save()
    }

    // MARK: - Projects

    func getAllProjectNames() -> [String] {
        Array(Set(tasks.compactMap { $0.project.isEmpty ? nil : $0.project })).sorted()
    }

    /// Port of getProjectColor() in taskStore.ts — explicit Project.color if set, else a
    /// deterministic hash into the shared palette so unlabeled projects still get a stable color.
    func projectColor(for projectName: String) -> Color? {
        guard !projectName.isEmpty else { return nil }
        if let proj = projects.first(where: { $0.name == projectName }), let hex = proj.color {
            return Color(hexString: hex)
        }
        var hash: UInt32 = 0
        for unit in projectName.utf16 { hash = hash &* 31 &+ UInt32(unit) }
        let idx = Int(hash % UInt32(projectColorPalette.count))
        return Color(hexString: projectColorPalette[idx])
    }

    func setTaskProject(_ task: TaskItem, to projectName: String) {
        task.project = projectName
        save()
        guard !projectName.isEmpty else { return }
        let alreadyHasSplit = splits.contains { $0.rules.projects.contains(projectName) }
        if !alreadyHasSplit {
            _ = createSplit(name: projectName, rules: SplitRules(projects: [projectName]), ruleOperator: .AND, enabled: true)
            addToast("◈ \"\(projectName)\" split created")
        }
    }

    func navigateToProject(_ name: String) {
        activeView = .project
        activeSplitID = nil
        selectedProject = name
        selectedIndex = 0
        isDetailOpen = false
        selectedTaskIDs.removeAll()
        activePicker = nil
        pickerTaskID = nil
        isProjectNavOpen = false
        selectedTaskID = getVisibleTasks().first?.id
    }

    /// Bulk-rename every task in a project, then fix any split rules that referenced it.
    func renameProject(_ old: String, to new: String) {
        guard !old.isEmpty, !new.isEmpty, old != new else { return }
        for task in tasks where task.project == old { task.project = new }
        for split in splits where split.rules.projects.contains(old) {
            split.rules.projects = split.rules.projects.map { $0 == old ? new : $0 }
        }
        save()
    }

    // MARK: - Splits

    @discardableResult
    func createSplit(name: String, rules: SplitRules, ruleOperator: RuleOperator, enabled: Bool) -> Split {
        let maxOrder = splits.map(\.sortOrder).max() ?? -1
        let split = Split(name: name, rules: rules, ruleOperator: ruleOperator, enabled: enabled, sortOrder: maxOrder + 1)
        context.insert(split)
        splits.append(split)
        save()
        return split
    }

    func updateSplit(_ split: Split, _ body: (Split) -> Void) {
        body(split)
        save()
    }

    func deleteSplit(_ split: Split) {
        splits.removeAll { $0.id == split.id }
        if activeSplitID == split.id {
            activeSplitID = nil
            activeView = .inbox
        }
        context.delete(split)
        save()
    }

    func setActiveSplit(_ id: UUID) {
        activeView = .split
        activeSplitID = id
        selectedIndex = 0
        isDetailOpen = false
        selectedTaskIDs.removeAll()
        activePicker = nil
        pickerTaskID = nil
        showCompletedInView = false
        selectedTaskID = getVisibleTasks().first?.id
    }

    func moveSplit(_ split: Split, dir: Int) {
        let enabled = splits.filter(\.enabled).sorted { $0.sortOrder < $1.sortOrder }
        guard let idx = enabled.firstIndex(where: { $0.id == split.id }) else { return }
        let swapIdx = idx + dir
        guard enabled.indices.contains(swapIdx) else { return }
        let a = enabled[idx], b = enabled[swapIdx]
        let tmp = a.sortOrder
        a.sortOrder = b.sortOrder
        b.sortOrder = tmp
        save()
    }

    func getSplitTaskCount(_ splitID: UUID) -> Int {
        guard let split = splits.first(where: { $0.id == splitID }) else { return 0 }
        return applySplitFilter(tasks, split).filter { $0.status != .done && $0.status != .archived }.count
    }

    // MARK: - Tabs

    func getOrderedTabs() -> [TabEntry] {
        let builtins: [TabEntry] = Self.builtinTabs.map { .builtin($0) }
        let splitTabs: [TabEntry] = splits.filter(\.enabled).sorted { $0.sortOrder < $1.sortOrder }.map { .split($0.id) }
        return builtins + splitTabs
    }

    func navigateToTab(_ tab: TabEntry) {
        switch tab {
        case .builtin(let view): setView(view)
        case .split(let id): setActiveSplit(id)
        }
    }

    func navigateTabRelative(_ dir: Int) {
        let tabs = getOrderedTabs()
        guard !tabs.isEmpty else { return }
        let currentIdx = tabs.firstIndex { tab in
            switch tab {
            case .builtin(let v): return activeView == v
            case .split(let id): return activeSplitID == id
            }
        } ?? 0
        let next = ((currentIdx + dir) % tabs.count + tabs.count) % tabs.count
        navigateToTab(tabs[next])
    }

    // MARK: - Settings

    func setSettingsOpen(_ v: Bool) {
        isSettingsOpen = v
        if v { settingsSection = nil }
    }

    // MARK: - Onboarding

    func completeOnboarding(withDemoData: Bool) {
        if withDemoData {
            DemoData.seed(context: context)
        }
        onboardingCompleted = true
        loadTasks()
    }

    // MARK: - Computed: visible tasks

    func getVisibleTasks() -> [TaskItem] {
        switch activeView {
        case .inbox:
            return tasks
                .filter { $0.status == .inbox && !$0.hasUpcomingStart && $0.dueDate == nil }
                .sorted { $0.sortOrder > $1.sortOrder }

        case .today:
            let cal = Calendar.current
            return tasks
                .filter { task in
                    guard task.status != .done, !task.hasUpcomingStart, let due = task.dueDate else { return false }
                    return cal.startOfDay(for: due) <= cal.startOfDay(for: .now)
                }
                .sorted { $0.sortOrder > $1.sortOrder }

        case .tomorrow:
            let cal = Calendar.current
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: .now) else { return [] }
            return tasks
                .filter { task in
                    guard task.status != .done, task.status != .archived, let due = task.dueDate else { return false }
                    return cal.isDate(due, inSameDayAs: tomorrow)
                }
                .sorted { $0.sortOrder > $1.sortOrder }

        case .week:
            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            guard let weekOut = cal.date(byAdding: .day, value: 7, to: today) else { return [] }
            return tasks
                .filter { task in
                    guard task.status != .done, task.status != .archived, let due = task.dueDate else { return false }
                    let day = cal.startOfDay(for: due)
                    return day >= today && day <= weekOut
                }
                .sorted { a, b in
                    if let da = a.dueDate, let db = b.dueDate, da != db { return da < db }
                    return a.sortOrder > b.sortOrder
                }

        case .upcoming:
            return tasks
                .filter { $0.status != .archived && $0.status != .done && $0.hasUpcomingStart }
                .sorted { a, b in
                    switch (a.startDate, b.startDate) {
                    case let (da?, db?) where da != db: return da < db
                    default: return a.createdAt > b.createdAt
                    }
                }

        case .all:
            return tasks
                .filter { $0.status != .archived && !$0.hasUpcomingStart }
                .sorted { a, b in
                    let pa = a.project.isEmpty ? "\u{FFFF}" : a.project
                    let pb = b.project.isEmpty ? "\u{FFFF}" : b.project
                    if pa != pb { return pa < pb }
                    return a.sortOrder > b.sortOrder
                }

        case .done:
            return tasks
                .filter { $0.status == .done }
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        case .project:
            return tasks
                .filter { $0.project == selectedProject && $0.status != .archived && (showCompletedInView || $0.status != .done) }
                .sorted { $0.sortOrder > $1.sortOrder }

        case .split:
            guard let id = activeSplitID, let split = splits.first(where: { $0.id == id }) else { return [] }
            return applySplitFilter(tasks, split)
                .filter { showCompletedInView || $0.status != .done }
                .sorted { $0.sortOrder > $1.sortOrder }
        }
    }
}

enum SplitEditorIntent {
    case split
    case filter
}

/// Standalone so it can be unit-tested/reused without an AppStore instance.
func applySplitFilter(_ tasks: [TaskItem], _ split: Split) -> [TaskItem] {
    let base = tasks.filter { $0.status != .archived }
    let rules = split.rules
    var matchers: [(TaskItem) -> Bool] = []
    if !rules.projects.isEmpty { matchers.append { rules.projects.contains($0.project) } }
    if !rules.labels.isEmpty { matchers.append { task in task.labels.contains { rules.labels.contains($0) } } }
    if !rules.priorities.isEmpty { matchers.append { rules.priorities.contains($0.priority) } }
    if let dueBefore = rules.dueBefore { matchers.append { ($0.dueDate.map { $0 < dueBefore }) ?? false } }
    if let dueAfter = rules.dueAfter { matchers.append { ($0.dueDate.map { $0 > dueAfter }) ?? false } }
    if let starred = rules.starred { matchers.append { $0.starred == starred } }
    guard !matchers.isEmpty else { return base }
    return base.filter { task in
        split.ruleOperator == .AND ? matchers.allSatisfy { $0(task) } : matchers.contains { $0(task) }
    }
}

/// Immutable copy of a TaskItem's fields, used to restore a deleted task on undo
/// (SwiftData deletes are not otherwise reversible).
private struct TaskSnapshot {
    let id: UUID
    let title: String
    let notes: String
    let status: TaskStatus
    let priority: TaskPriority
    let dueDate: Date?
    let startDate: Date?
    let reminder: Date?
    let project: String
    let labels: [String]
    let createdAt: Date
    let completedAt: Date?
    let starred: Bool
    let sortOrder: Double

    init(_ t: TaskItem) {
        id = t.id; title = t.title; notes = t.notes; status = t.status; priority = t.priority
        dueDate = t.dueDate; startDate = t.startDate; reminder = t.reminder; project = t.project
        labels = t.labels; createdAt = t.createdAt; completedAt = t.completedAt
        starred = t.starred; sortOrder = t.sortOrder
    }

    func makeTask() -> TaskItem {
        TaskItem(
            id: id, title: title, notes: notes, status: status, priority: priority,
            dueDate: dueDate, startDate: startDate, reminder: reminder, project: project,
            labels: labels, createdAt: createdAt, completedAt: completedAt, starred: starred,
            sortOrder: sortOrder
        )
    }
}
