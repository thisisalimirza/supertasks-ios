import SwiftUI

struct NewProjectDialogView: View {
    @EnvironmentObject var store: AppStore
    @State private var name = ""
    @FocusState private var fieldFocused: Bool

    private var existingCount: Int { store.splits.filter(\.enabled).count }

    private func close() { store.isNewProjectOpen = false; name = "" }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { fieldFocused = true; return }
        let split = store.createSplit(name: trimmed, rules: SplitRules(projects: [trimmed]), ruleOperator: .AND, enabled: true)
        store.setActiveSplit(split.id)
        close()
    }

    var body: some View {
        OverlayCard(maxWidth: 400, topPadding: 100, onBackgroundTap: close) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("New Project").font(.system(size: 14, weight: .semibold)).foregroundStyle(store.colors.t1)
                    TextField("Project name…", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($fieldFocused)
                        .reportsTextFocus(fieldFocused, to: store)
                        .onSubmit(save)
                        .padding(10)
                        .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 8))
                    Text("Tasks assigned to this project will appear here automatically.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(store.colors.t7)
                    if existingCount >= splitViewSoftLimit {
                        Text("You already have \(existingCount) views. More than \(splitViewSoftLimit) can fragment your focus — consider consolidating before adding more.")
                            .font(.system(size: 10))
                            .foregroundStyle(store.colors.t6)
                    }
                }
                .padding(20)

                Divider().overlay(store.colors.b1)

                HStack {
                    Button("Cancel", action: close)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(store.colors.t6)
                    Spacer()
                    Button("Create Project", action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(store.colors.accent)
                }
                .padding(20)
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { fieldFocused = true } }
    }
}
