import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var store: AppStore
    @FocusState private var notesFocused: Bool
    @FocusState private var titleFocused: Bool

    private var task: TaskItem? { store.tasks.first { $0.id == store.selectedTaskID } }

    var body: some View {
        if let task {
            content(for: task)
        }
    }

    @ViewBuilder
    private func content(for task: TaskItem) -> some View {
        VStack(spacing: 0) {
            header(task)
            title(task)
            metadataRow(task)
            notes(task)
            footer
        }
        .background(store.colors.panel)
        .overlay(alignment: .leading) {
            Rectangle().fill(store.colors.b2).frame(width: 1)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { notesFocused = true }
        }
        .onChange(of: store.selectedTaskID) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { notesFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .supertasksFocusNotes)) { _ in
            notesFocused = true
        }
    }

    private func header(_ task: TaskItem) -> some View {
        HStack {
            Button { store.closeDetail() } label: {
                Label("Close", systemImage: "chevron.left")
                    .font(.system(size: 13))
                    .foregroundStyle(store.colors.t6)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { store.cyclePriority(task) } label: {
                HStack(spacing: 6) {
                    PriorityDotView(priority: task.priority, size: 8)
                    Text(task.priority.displayName).font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(store.colors.priorityColor(task.priority))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(
                    task.priority == .none ? store.colors.btn : store.colors.priorityColor(task.priority).opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }
            .buttonStyle(.plain)

            Button { store.toggleStar(task) } label: {
                Text("★")
                    .font(.system(size: 15))
                    .foregroundStyle(task.starred ? store.colors.warn : store.colors.t6)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(store.colors.b1).frame(height: 1) }
    }

    private func title(_ task: TaskItem) -> some View {
        TextField("Task title", text: Binding(
            get: { task.title },
            set: { newValue in store.mutate(task) { $0.title = newValue } }
        ))
        .textFieldStyle(.plain)
        .font(.system(size: 19, weight: .medium))
        .foregroundStyle(store.colors.t1)
        .focused($titleFocused)
        .reportsTextFocus(titleFocused, to: store)
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    private func metadataRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Text(task.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(store.colors.t6)

            if let completedAt = task.completedAt {
                Text("Done \(completedAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(store.colors.success)
            }

            Button { store.setActivePicker(.due, taskID: task.id) } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 11))
                    Text(task.dueDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "Due date")
                }
                .font(.system(size: 12))
                .foregroundStyle(task.dueDate != nil ? store.colors.t1 : store.colors.t6)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button { store.setActivePicker(.startDate, taskID: task.id) } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 11))
                    Text(task.startDate.map { "From \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? "Hold until")
                }
                .font(.system(size: 12))
                .foregroundStyle(task.startDate != nil ? store.colors.t1 : store.colors.t6)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func notes(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(store.colors.t6)

            TextEditor(text: Binding(
                get: { task.notes },
                set: { newValue in store.mutate(task) { $0.notes = newValue } }
            ))
            .font(.system(size: 14))
            .foregroundStyle(store.colors.t3)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .focused($notesFocused)
            .reportsTextFocus(notesFocused, to: store)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Text("⌘↩ close")
            Text("⌘⇧, priority")
            Text("Esc close")
        }
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(store.colors.t8)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(store.colors.b1).frame(height: 1) }
    }
}
