import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var store: AppStore
    let task: TaskItem
    let isSelected: Bool
    let isChecked: Bool

    @State private var editValue = ""
    @FocusState private var titleFocused: Bool
    @State private var isCompleting = false

    private var isEditing: Bool { store.editingTaskID == task.id }
    private var isDone: Bool { task.status == .done }
    private var projectColor: Color? { store.projectColor(for: task.project) }

    var body: some View {
        HStack(spacing: 12) {
            doneCheckbox
            bulkCheckbox
            PriorityDotView(priority: task.priority)
            titleColumn
            Spacer(minLength: 8)
            metadata
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if let projectColor {
                Rectangle().fill(projectColor.opacity(0.7)).frame(width: 3)
            } else if isSelected {
                Rectangle().fill(store.colors.accent).frame(width: 3)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(store.colors.b0).frame(height: 1) }
        .opacity(isDone ? 0.5 : 1)
        .offset(x: isCompleting ? 48 : 0)
        .opacity(isCompleting ? 0 : 1)
        .animation(.easeIn(duration: 0.2), value: isCompleting)
        .onChange(of: store.completingTaskID) { _, newValue in
            isCompleting = (newValue == task.id)
        }
        .onTapGesture {
            if let idx = store.getVisibleTasks().firstIndex(where: { $0.id == task.id }) {
                store.setSelectedIndex(idx)
            }
            store.openDetail(task.id)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                store.toggleDone(task)
            } label: {
                Label(isDone ? "Reopen" : "Done", systemImage: isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(store.colors.success)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { store.deleteTask(task) } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { store.toggleStar(task) } label: {
                Label(task.starred ? "Unstar" : "Star", systemImage: task.starred ? "star.slash" : "star")
            }
            .tint(store.colors.warn)
        }
        .contextMenu { contextMenuItems }
        .draggable(task.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let sourceIDString = items.first, let sourceID = UUID(uuidString: sourceIDString) else { return false }
            store.moveTaskToPosition(sourceID: sourceID, targetID: task.id)
            return true
        }
    }

    private var rowBackground: some View {
        Group {
            if isSelected || isChecked {
                store.colors.sel
            } else {
                Color.clear
            }
        }
    }

    private var doneCheckbox: some View {
        Button {
            store.toggleDone(task)
        } label: {
            ZStack {
                Circle().strokeBorder(store.colors.b3, lineWidth: 1).frame(width: 16, height: 16)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(store.colors.success)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var bulkCheckbox: some View {
        Button { store.toggleSelectTask(task.id) } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(isChecked ? store.colors.accent : Color.clear)
                .strokeBorder(isChecked ? Color.clear : store.colors.b3, lineWidth: 1)
                .frame(width: 14, height: 14)
                .overlay {
                    if isChecked {
                        Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .opacity(isChecked ? 1 : 0.4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var titleColumn: some View {
        if isEditing {
            TextField("", text: $editValue)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(store.colors.t1)
                .focused($titleFocused)
                .reportsTextFocus(titleFocused, to: store)
                .onAppear { editValue = task.title; titleFocused = true }
                .onSubmit { commitEdit() }
                .onChange(of: titleFocused) { _, focused in
                    if !focused { commitEdit() }
                }
        } else {
            HStack(spacing: 16) {
                Text(task.title)
                    .font(.system(size: 14))
                    .foregroundStyle(isDone ? store.colors.t6 : store.colors.t1)
                    .strikethrough(isDone)
                    .lineLimit(1)
                if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(task.notes.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " · "))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(store.colors.t7)
                        .lineLimit(1)
                }
            }
        }
    }

    private func commitEdit() {
        let trimmed = editValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.mutate(task) { $0.title = trimmed }
        }
        store.editingTaskID = nil
    }

    private var metadata: some View {
        HStack(spacing: 8) {
            if task.starred {
                Text("★").font(.system(size: 11)).foregroundStyle(store.colors.warn)
            }
            ForEach(task.labels.prefix(2), id: \.self) { label in
                Text(label)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(store.colors.t6)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 4))
            }
            if !task.project.isEmpty {
                Text(task.project)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(store.colors.t7)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 4))
            }
            if let due = task.dueDate {
                Text(due.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(due < .now && !isDone ? store.colors.danger : store.colors.t6)
            }
        }
    }

    @ViewBuilder private var contextMenuItems: some View {
        Button { store.toggleDone(task) } label: {
            Label(isDone ? "Mark incomplete" : "Mark as done", systemImage: "checkmark.circle")
        }
        Button { store.toggleStar(task) } label: {
            Label(task.starred ? "Unstar" : "Star", systemImage: task.starred ? "star.slash" : "star")
        }
        Button { store.cyclePriority(task) } label: {
            Label("Cycle priority", systemImage: "flag")
        }
        Button { store.editingTaskID = task.id } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button { store.setActivePicker(.due, taskID: task.id) } label: {
            Label("Set due date", systemImage: "calendar")
        }
        Button { store.setActivePicker(.startDate, taskID: task.id) } label: {
            Label("Hold until…", systemImage: "clock")
        }
        Button { store.setActivePicker(.label, taskID: task.id) } label: {
            Label("Edit labels", systemImage: "tag")
        }
        Button { store.setActivePicker(.project, taskID: task.id) } label: {
            Label("Assign project", systemImage: "folder")
        }
        Button { store.toggleSelectTask(task.id) } label: {
            Label(isChecked ? "Deselect" : "Select", systemImage: "checkmark.circle.badge.questionmark")
        }
        Divider()
        Button(role: .destructive) { store.deleteTask(task) } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
