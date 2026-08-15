import SwiftUI

struct ProjectNavOverlayView: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    @FocusState private var fieldFocused: Bool

    private var filtered: [String] {
        FuzzySearch.search(store.getAllProjectNames(), query: query) { [$0] }
    }

    private var taskCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for task in store.tasks where !task.project.isEmpty && task.status != .archived && task.status != .done {
            counts[task.project, default: 0] += 1
        }
        return counts
    }

    private func close() { store.isProjectNavOpen = false }

    var body: some View {
        OverlayCard(maxWidth: 500, topPadding: 90, onBackgroundTap: close) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("◈").foregroundStyle(store.colors.t6)
                    TextField("Jump to project…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(store.colors.t1)
                        .focused($fieldFocused)
                        .reportsTextFocus(fieldFocused, to: store)
                        .onSubmit { if let first = filtered.first { navigate(first) } }
                    Text("ESC").font(.system(size: 10, design: .monospaced)).foregroundStyle(store.colors.t6)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .overlay(alignment: .bottom) { Rectangle().fill(store.colors.b1).frame(height: 1) }

                ScrollView {
                    if filtered.isEmpty {
                        Text(store.getAllProjectNames().isEmpty
                             ? "No projects yet — assign a project to a task to create one"
                             : "No results for \"\(query)\"")
                            .font(.system(size: 14))
                            .foregroundStyle(store.colors.t6)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered, id: \.self) { project in
                                Button { navigate(project) } label: {
                                    HStack(spacing: 10) {
                                        Text("◈").font(.system(size: 11, design: .monospaced)).foregroundStyle(store.colors.t6)
                                        Text(project).font(.system(size: 14)).foregroundStyle(store.colors.t2)
                                        Spacer()
                                        if let count = taskCounts[project] {
                                            Text("\(count)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(store.colors.t7)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .onAppear { fieldFocused = true }
    }

    private func navigate(_ project: String) {
        store.navigateToProject(project)
    }
}
