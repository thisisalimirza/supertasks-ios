import SwiftUI

private struct CreationDefaults {
    var dueDate: Date?
    var startDate: Date?
    var project: String = ""
    var hint: String?
}

/// Port of useCreationDefaults() in InlineTaskCreator.tsx — smart-fills the due date /
/// project based on whichever view the user is currently in.
private func creationDefaults(store: AppStore) -> CreationDefaults {
    let today = Calendar.current.startOfDay(for: .now)

    switch store.activeView {
    case .today, .week:
        return CreationDefaults(dueDate: today, hint: "Due today")
    case .tomorrow:
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        return CreationDefaults(dueDate: tomorrow, hint: "Due tomorrow")
    case .project:
        if let project = store.selectedProject {
            return CreationDefaults(project: project, hint: "◈ \(project)")
        }
    case .split:
        if let id = store.activeSplitID, let split = store.splits.first(where: { $0.id == id }) {
            var defaults = CreationDefaults()
            var hints: [String] = []
            if split.rules.projects.count == 1 {
                defaults.project = split.rules.projects[0]
                hints.append("◈ \(split.rules.projects[0])")
            }
            if split.rules.dueBefore != nil || split.rules.dueAfter != nil {
                defaults.dueDate = today
                hints.append("Due today")
            }
            if !hints.isEmpty {
                defaults.hint = hints.joined(separator: " · ")
                return defaults
            }
        }
    default:
        break
    }
    return CreationDefaults()
}

struct InlineTaskCreatorView: View {
    @EnvironmentObject var store: AppStore
    @State private var value = ""
    @FocusState private var focused: Bool

    var body: some View {
        let defaults = creationDefaults(store: store)

        HStack(spacing: 12) {
            Circle()
                .strokeBorder(store.colors.accent, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(width: 16, height: 16)
            Color.clear.frame(width: 14, height: 14)
            Color.clear.frame(width: 6, height: 6)

            TextField("New task…", text: $value)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(store.colors.t1)
                .focused($focused)
                .reportsTextFocus(focused, to: store)
                .onSubmit { commit(defaults: defaults) }

            if let hint = defaults.hint {
                Text(hint)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(store.colors.accent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(store.colors.sel, in: RoundedRectangle(cornerRadius: 4))
            }

            Text("↵ save")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(store.colors.t8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(store.colors.creator)
        .overlay(alignment: .bottom) { Rectangle().fill(store.colors.b2).frame(height: 1) }
        .onAppear { focused = true }
    }

    private func commit(defaults: CreationDefaults) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.createTask(title: trimmed, dueDate: defaults.dueDate, startDate: defaults.startDate, project: defaults.project)
        }
        store.finishCreating()
        value = ""
    }
}
