import SwiftUI

struct ProjectPickerView: View {
    @EnvironmentObject var store: AppStore
    let task: TaskItem
    @State private var query = ""
    @FocusState private var fieldFocused: Bool

    private var filtered: [String] {
        FuzzySearch.search(store.getAllProjectNames(), query: query) { [$0] }
    }

    var body: some View {
        OverlayCard(maxWidth: 420, onBackgroundTap: { store.closePicker() }) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Assign project")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.colors.t1)

                TextField("Search or create project…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($fieldFocused)
                    .reportsTextFocus(fieldFocused, to: store)
                    .padding(10)
                    .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 8))

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !task.project.isEmpty {
                            row(name: "No project", color: nil, isCurrent: false) {
                                store.setTaskProject(task, to: "")
                                store.closePicker()
                            }
                        }
                        ForEach(filtered, id: \.self) { name in
                            row(name: name, color: store.projectColor(for: name), isCurrent: task.project == name) {
                                store.setTaskProject(task, to: name)
                                store.closePicker()
                            }
                        }
                        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !filtered.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                            Button {
                                store.setTaskProject(task, to: trimmed)
                                store.closePicker()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle").foregroundStyle(store.colors.accent)
                                    Text("Create \u{201C}\(trimmed)\u{201D}").foregroundStyle(store.colors.accent)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
            .padding(20)
        }
    }

    private func row(name: String, color: Color?, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let color {
                    Circle().fill(color).frame(width: 8, height: 8)
                }
                Text(name).foregroundStyle(store.colors.t2)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark").foregroundStyle(store.colors.accent)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
