import SwiftUI

private enum TaskListRow: Identifiable, Hashable {
    case groupHeader(String)
    case task(UUID, Int)

    var id: String {
        switch self {
        case .groupHeader(let s): return "header-\(s)"
        case .task(let id, _): return "task-\(id)"
        }
    }
}

private let builtinViewOrder: [TaskViewKind] = [.inbox, .today, .upcoming, .all, .done]
private let builtinViewLabels: [TaskViewKind: String] = [
    .inbox: "Inbox", .today: "Today", .tomorrow: "Tomorrow", .week: "This Week",
    .upcoming: "Upcoming", .all: "All Tasks", .done: "Done",
]

struct TaskListView: View {
    @EnvironmentObject var store: AppStore
    @State private var splitContextMenuTarget: Split?

    private var visibleTasks: [TaskItem] { store.getVisibleTasks() }
    private var isEmpty: Bool { visibleTasks.isEmpty && !store.isCreating }
    private var activeSplit: Split? {
        store.activeView == .split ? store.splits.first { $0.id == store.activeSplitID } : nil
    }

    private var rows: [TaskListRow] {
        var rows: [TaskListRow] = []
        var lastProject: String?
        var sawFirst = false
        for (index, task) in visibleTasks.enumerated() {
            if store.activeView == .all {
                let proj = task.project.isEmpty ? nil : task.project
                if !sawFirst || proj != lastProject {
                    lastProject = proj
                    sawFirst = true
                    rows.append(.groupHeader(proj ?? "\u{0}no-project"))
                }
            }
            rows.append(.task(task.id, index))
        }
        return rows
    }

    var body: some View {
        ZStack {
            if isEmpty {
                EmptyStateView(config: emptyConfig(for: store.activeView, activeSplit: activeSplit, selectedProject: store.selectedProject))
            }

            VStack(spacing: 0) {
                header
                if store.isCreating { InlineTaskCreatorView() }
                list
            }

            addButton
        }
        .background(isEmpty ? Color.clear : store.colors.bg)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    if store.activeView == .project, let name = store.selectedProject {
                        HStack(spacing: 4) {
                            Text("◈").foregroundStyle(isEmpty ? .white.opacity(0.5) : store.colors.t6)
                            Text(name).font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(isEmpty ? .white.opacity(0.9) : store.colors.t1)
                    }

                    ForEach(builtinViewOrder, id: \.self) { view in
                        viewTabButton(view)
                    }

                    let enabledSplits = store.splits.filter(\.enabled).sorted { $0.sortOrder < $1.sortOrder }
                    if !enabledSplits.isEmpty {
                        Rectangle()
                            .fill(isEmpty ? Color.white.opacity(0.2) : store.colors.b3)
                            .frame(width: 1, height: 16)
                    }
                    ForEach(enabledSplits) { split in
                        splitTabButton(split)
                    }

                    Button {
                        store.isSplitEditorOpen = true
                        store.editingSplitID = nil
                        store.splitEditorIntent = .split
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isEmpty ? .white.opacity(0.5) : store.colors.t7)
                            .frame(width: 20, height: 20)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("\(visibleTasks.count) \(visibleTasks.count == 1 ? "task" : "tasks")")
                if !store.selectedTaskIDs.isEmpty {
                    Text("· \(store.selectedTaskIDs.count) selected").foregroundStyle(store.colors.accent)
                }
                if store.activeView == .project || store.activeView == .split {
                    Button {
                        store.showCompletedInView.toggle()
                    } label: {
                        Text("· \(store.showCompletedInView ? "hide completed" : "show completed")")
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(isEmpty ? .white.opacity(0.4) : store.colors.t8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private func viewTabButton(_ view: TaskViewKind) -> some View {
        let isActive = store.activeView == view
        return Button { store.setView(view) } label: {
            Text(builtinViewLabels[view] ?? "")
                .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                .foregroundStyle(
                    isActive
                        ? (isEmpty ? .white.opacity(0.9) : store.colors.t1)
                        : (isEmpty ? .white.opacity(0.4) : store.colors.t6)
                )
        }
        .buttonStyle(.plain)
    }

    private func splitTabButton(_ split: Split) -> some View {
        let isActive = store.activeView == .split && store.activeSplitID == split.id
        let count = store.getSplitTaskCount(split.id)
        let color = split.rules.projects.count == 1 ? store.projectColor(for: split.rules.projects[0]) : nil

        return Button { store.setActiveSplit(split.id) } label: {
            HStack(spacing: 6) {
                if let color { Circle().fill(color.opacity(0.8)).frame(width: 6, height: 6) }
                Text(split.name)
                    .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(isEmpty ? Color.white.opacity(0.12) : store.colors.btn, in: Capsule())
                }
            }
            .foregroundStyle(
                isActive
                    ? (isEmpty ? .white.opacity(0.9) : store.colors.t1)
                    : (isEmpty ? .white.opacity(0.4) : store.colors.t6)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { store.isSplitEditorOpen = true; store.editingSplitID = split.id; store.splitEditorIntent = .split } label: {
                Label("Edit Split", systemImage: "pencil")
            }
            Button { store.updateSplit(split) { $0.enabled.toggle() } } label: {
                Label(split.enabled ? "Disable Split" : "Enable Split", systemImage: "eye.slash")
            }
            Button { store.moveSplit(split, dir: -1) } label: { Label("Move Left", systemImage: "arrow.left") }
            Button { store.moveSplit(split, dir: 1) } label: { Label("Move Right", systemImage: "arrow.right") }
            Divider()
            Button(role: .destructive) { store.deleteSplit(split) } label: { Label("Delete Split", systemImage: "trash") }
        }
    }

    // MARK: List

    private var list: some View {
        List {
            ForEach(rows) { row in
                switch row {
                case .groupHeader(let key):
                    Text(key == "\u{0}no-project" ? "No Project" : "◈ \(key)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(store.colors.t7)
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .padding(.bottom, 4)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                case .task(let id, let index):
                    if let task = store.tasks.first(where: { $0.id == id }) {
                        TaskRowView(task: task, isSelected: index == store.selectedIndex, isChecked: store.selectedTaskIDs.contains(id))
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .id(id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(isEmpty ? Color.clear : store.colors.bg)
        .environment(\.defaultMinListRowHeight, 1)
    }

    // MARK: Add button (touch equivalent of the `C` shortcut)

    private var addButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button { store.beginCreating() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(store.colors.accent, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .padding(24)
            }
        }
    }
}
