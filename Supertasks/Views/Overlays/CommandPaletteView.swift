import SwiftUI

private enum CommandItemType {
    case create, navigate, action, result, setting
}

private struct CommandItem: Identifiable {
    let id: String
    let label: String
    let description: String?
    var notes: String?
    let group: String
    let type: CommandItemType
    let action: () -> Void
}

/// Generic-actions rows that duplicate a more specific Task-group item and should be hidden.
private let excludedShortcutLabels: Set<String> = ["⌘K", "⌘⇧L", "E", "D", "S", "R", "H", "L", "X", "⌫"]

struct CommandPaletteView: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    @State private var activeIndex = 0
    @FocusState private var fieldFocused: Bool

    private var selectedTask: TaskItem? {
        let visible = store.getVisibleTasks()
        return visible[safe: store.selectedIndex]
    }

    private func buildItems() -> [CommandItem] {
        var items: [CommandItem] = []

        if let task = selectedTask {
            let isDone = task.status == .done
            items.append(contentsOf: [
                CommandItem(id: "task-done", label: isDone ? "Mark incomplete" : "Mark as done", description: nil, group: "Task", type: .action) { store.toggleDone(task); close() },
                CommandItem(id: "task-star", label: task.starred ? "Unstar" : "Star task", description: nil, group: "Task", type: .action) { store.toggleStar(task); close() },
                CommandItem(id: "task-priority", label: "Cycle priority", description: nil, group: "Task", type: .action) { store.cyclePriority(task); close() },
                CommandItem(id: "task-due", label: "Set due date", description: nil, group: "Task", type: .action) { store.setActivePicker(.due, taskID: task.id); close() },
                CommandItem(id: "task-start", label: "Set start date", description: nil, group: "Task", type: .action) { store.setActivePicker(.startDate, taskID: task.id); close() },
                CommandItem(id: "task-labels", label: "Edit labels", description: nil, group: "Task", type: .action) { store.setActivePicker(.label, taskID: task.id); close() },
                CommandItem(id: "task-project", label: "Assign project", description: nil, group: "Task", type: .action) { store.setActivePicker(.project, taskID: task.id); close() },
                CommandItem(id: "task-delete", label: "Delete task", description: nil, group: "Task", type: .action) { store.deleteTask(task); close() },
            ])
        }

        items.append(contentsOf: [
            CommandItem(id: "view-inbox", label: "Inbox", description: nil, group: "Go To", type: .navigate) { store.setView(.inbox); close() },
            CommandItem(id: "view-today", label: "Today", description: nil, group: "Go To", type: .navigate) { store.setView(.today); close() },
            CommandItem(id: "view-tomorrow", label: "Tomorrow", description: nil, group: "Go To", type: .navigate) { store.setView(.tomorrow); close() },
            CommandItem(id: "view-week", label: "This Week", description: nil, group: "Go To", type: .navigate) { store.setView(.week); close() },
            CommandItem(id: "view-all", label: "All Tasks", description: nil, group: "Go To", type: .navigate) { store.setView(.all); close() },
            CommandItem(id: "view-done", label: "Done", description: nil, group: "Go To", type: .navigate) { store.setView(.done); close() },
        ])
        for split in store.splits.filter(\.enabled) {
            items.append(CommandItem(id: "view-split-\(split.id)", label: split.name, description: "View", group: "Go To", type: .navigate) { store.setActiveSplit(split.id); close() })
        }

        items.append(CommandItem(id: "project-new", label: "New Project", description: "Create a project", group: "Projects", type: .create) { store.isNewProjectOpen = true; close() })
        for name in store.getAllProjectNames() {
            items.append(CommandItem(id: "project-go-\(name)", label: name, description: "Project", group: "Projects", type: .navigate) { store.navigateToProject(name); close() })
        }

        items.append(contentsOf: [
            CommandItem(id: "filter-new", label: "New Filter", description: "Filter current tasks", group: "Filters", type: .navigate) { openSplitEditor(nil, intent: .filter); close() },
            CommandItem(id: "filter-priority", label: "Filter by Priority", description: nil, group: "Filters", type: .navigate) { openSplitEditor(nil, intent: .filter); close() },
            CommandItem(id: "filter-label", label: "Filter by Label", description: nil, group: "Filters", type: .navigate) { openSplitEditor(nil, intent: .filter); close() },
            CommandItem(id: "filter-project", label: "Filter by Project", description: nil, group: "Filters", type: .navigate) { openSplitEditor(nil, intent: .filter); close() },
        ])

        items.append(CommandItem(id: "split-create", label: "New Split View", description: "Advanced filter tab", group: "Splits", type: .create) { openSplitEditor(nil, intent: .split); close() })
        if store.activeView == .split, let activeID = store.activeSplitID, let active = store.splits.first(where: { $0.id == activeID }) {
            items.append(contentsOf: [
                CommandItem(id: "split-edit", label: "Edit \"\(active.name)\"", description: nil, group: "Splits", type: .action) { openSplitEditor(active.id, intent: .split); close() },
                CommandItem(id: "split-disable", label: "Disable \"\(active.name)\"", description: nil, group: "Splits", type: .action) { store.updateSplit(active) { $0.enabled = false }; store.setView(.inbox); close() },
                CommandItem(id: "split-delete", label: "Delete \"\(active.name)\"", description: nil, group: "Splits", type: .action) { store.deleteSplit(active); close() },
            ])
        }
        for split in store.splits where split.id != store.activeSplitID {
            items.append(CommandItem(id: "split-edit-\(split.id)", label: "Edit \"\(split.name)\"", description: "Split", group: "Splits", type: .action) { openSplitEditor(split.id, intent: .split); close() })
        }

        items.append(contentsOf: [
            CommandItem(id: "toggle-theme", label: store.theme == .dark ? "Switch to Light Mode" : "Switch to Dark Mode", description: "⌘⇧L", group: "Settings", type: .action) { store.toggleTheme(); close() },
            CommandItem(id: "open-settings", label: "Open Settings", description: "/", group: "Settings", type: .setting) { store.setSettingsOpen(true); close() },
            CommandItem(id: "settings-appearance", label: "Settings → Appearance", description: nil, group: "Settings", type: .setting) { store.setSettingsOpen(true); store.settingsSection = .appearance; close() },
            CommandItem(id: "settings-labels", label: "Settings → Labels", description: nil, group: "Settings", type: .setting) { store.setSettingsOpen(true); store.settingsSection = .labels; close() },
            CommandItem(id: "settings-views", label: "Settings → Views & Projects", description: nil, group: "Settings", type: .setting) { store.setSettingsOpen(true); store.settingsSection = .views; close() },
            CommandItem(id: "settings-data", label: "Settings → Data", description: nil, group: "Settings", type: .setting) { store.setSettingsOpen(true); store.settingsSection = .data; close() },
        ])

        for shortcut in ShortcutCatalog.all where !excludedShortcutLabels.contains(shortcut.keyLabel) {
            items.append(CommandItem(id: "action-\(shortcut.keyLabel)", label: shortcut.description, description: shortcut.keyLabel, group: "Actions", type: .action) {
                // Generic actions are shown for discoverability; hardware-keyboard users trigger
                // them directly. Escape is the one exception worth wiring here.
                close()
            })
        }

        for task in store.tasks.prefix(50) {
            items.append(CommandItem(id: "task-\(task.id)", label: task.title, description: task.project.isEmpty ? nil : task.project, notes: task.notes, group: "Tasks", type: .result) { store.openDetail(task.id); close() })
        }

        return items
    }

    private func openSplitEditor(_ id: UUID?, intent: SplitEditorIntent) {
        store.editingSplitID = id
        store.splitEditorIntent = intent
        store.isSplitEditorOpen = true
    }

    private func close() { store.isCommandPaletteOpen = false }

    var body: some View {
        let allItems = buildItems()
        let recent: [CommandItem] = store.recentCommandIDs.compactMap { id in allItems.first { $0.id == id } }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered: [CommandItem] = trimmedQuery.isEmpty
            ? Array(allItems.prefix(30))
            : FuzzySearch.search(allItems, query: trimmedQuery) { [$0.label, $0.description ?? "", $0.group, $0.notes ?? ""] }

        let grouped: [(String, [CommandItem])] = {
            if trimmedQuery.isEmpty {
                var groups: [(String, [CommandItem])] = []
                let taskActions = allItems.filter { $0.group == "Task" }
                let rest = filtered.filter { $0.group != "Task" }
                if let task = selectedTask, !taskActions.isEmpty {
                    let label = task.title.count > 32 ? String(task.title.prefix(32)) + "…" : task.title
                    groups.append((label, taskActions))
                } else if !recent.isEmpty {
                    groups.append(("Recent", recent))
                }
                for item in rest {
                    if let idx = groups.firstIndex(where: { $0.0 == item.group }) {
                        groups[idx].1.append(item)
                    } else {
                        groups.append((item.group, [item]))
                    }
                }
                return groups
            } else {
                var groups: [(String, [CommandItem])] = []
                for item in filtered {
                    let groupName = item.group == "Task" ? "Task Actions" : item.group
                    if let idx = groups.firstIndex(where: { $0.0 == groupName }) {
                        groups[idx].1.append(item)
                    } else {
                        groups.append((groupName, [item]))
                    }
                }
                return groups
            }
        }()

        let flat = grouped.flatMap(\.1)

        return OverlayCard(maxWidth: 600, topPadding: 70, onBackgroundTap: close) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(store.colors.t6)
                    TextField("Search tasks, actions, and more…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(store.colors.t1)
                        .focused($fieldFocused)
                        .reportsTextFocus(fieldFocused, to: store)
                        .onSubmit {
                            if let item = flat[safe: activeIndex] { execute(item) }
                        }
                    Text("ESC").font(.system(size: 10, design: .monospaced)).foregroundStyle(store.colors.t6)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .overlay(alignment: .bottom) { Rectangle().fill(store.colors.b1).frame(height: 1) }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(grouped, id: \.0) { groupName, items in
                            if store.commandPaletteGroupHeaders {
                                Text(groupName.uppercased())
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .tracking(1)
                                    .foregroundStyle(store.colors.t7)
                                    .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
                            }
                            ForEach(items) { item in
                                row(item, isActive: flat.firstIndex(where: { $0.id == item.id }) == activeIndex)
                            }
                        }
                        if flat.isEmpty {
                            Text("No results for \"\(query)\"")
                                .font(.system(size: 14))
                                .foregroundStyle(store.colors.t6)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 420)
            }
        }
        .onAppear { fieldFocused = true }
        .onChange(of: query) { _, _ in activeIndex = 0 }
    }

    private func row(_ item: CommandItem, isActive: Bool) -> some View {
        Button {
            execute(item)
        } label: {
            HStack(spacing: 10) {
                verb(for: item.type)
                Text(item.label)
                    .font(.system(size: 14))
                    .foregroundStyle(store.colors.t2)
                    .lineLimit(1)
                Spacer()
                if let description = item.description {
                    Text(description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(store.colors.t6)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(isActive ? store.colors.sel : Color.clear)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func verb(for type: CommandItemType) -> some View {
        let style = Font.system(size: 9, weight: .medium)
        switch type {
        case .create: Text("NEW").font(style).foregroundStyle(store.colors.accent).frame(width: 36, alignment: .leading)
        case .navigate: Text("GO TO").font(style).foregroundStyle(store.colors.t8).frame(width: 36, alignment: .leading)
        case .result, .setting: Text("OPEN").font(style).foregroundStyle(store.colors.t8).frame(width: 36, alignment: .leading)
        case .action: Color.clear.frame(width: 36, height: 1)
        }
    }

    private func execute(_ item: CommandItem) {
        store.addRecentCommand(item.id)
        item.action()
    }
}
