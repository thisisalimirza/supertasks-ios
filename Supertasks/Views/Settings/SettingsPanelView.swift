import SwiftUI

struct SettingsPanelView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(store.colors.b1)

            if let section = store.settingsSection {
                switch section {
                case .appearance: AppearanceSectionView()
                case .labels: LabelsSectionView()
                case .views: ViewsSectionView()
                case .data: DataSectionView()
                }
            } else {
                rootMenu
            }

            Divider().overlay(store.colors.b1)
            Text(store.settingsSection != nil ? "← back · Esc close" : "Tap to open · Esc close")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(store.colors.t8)
                .padding(.horizontal, 24).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(store.colors.panel)
        .overlay(alignment: .trailing) { Rectangle().fill(store.colors.b2).frame(width: 1) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let section = store.settingsSection {
                Button { store.settingsSection = nil } label: {
                    Label("Back", systemImage: "chevron.left").font(.system(size: 12)).foregroundStyle(store.colors.t6)
                }
                .buttonStyle(.plain)
                Text(section.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(store.colors.t1)
                Spacer()
            } else {
                Text("Settings").font(.system(size: 14, weight: .semibold)).foregroundStyle(store.colors.t1)
                Spacer()
            }
            Button { store.setSettingsOpen(false) } label: {
                Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(store.colors.t7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 16)
    }

    private var rootMenu: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    Button {
                        store.settingsSection = section
                    } label: {
                        HStack {
                            Text(section.title).font(.system(size: 14)).foregroundStyle(store.colors.t2)
                            Spacer()
                            if let meta = meta(for: section) {
                                Text(meta).font(.system(size: 11, design: .monospaced)).foregroundStyle(store.colors.t6)
                            }
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(store.colors.t7)
                        }
                        .padding(.horizontal, 24).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(store.colors.b0)
                }

                Button {
                    store.setSettingsOpen(false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { store.isShortcutCheatsheetOpen = true }
                } label: {
                    HStack {
                        Text("Keyboard shortcuts").font(.system(size: 14)).foregroundStyle(store.colors.t4)
                        Spacer()
                        Text("⌘/")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(store.colors.t7)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(.horizontal, 24).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
    }

    private func meta(for section: SettingsSection) -> String? {
        switch section {
        case .appearance: return store.theme.rawValue
        case .labels:
            let count = store.getAllLabels().count
            return count > 0 ? "\(count)" : nil
        case .views:
            let count = store.splits.filter(\.enabled).count
            return count > 0 ? "\(count)" : nil
        case .data:
            let count = store.tasks.filter { $0.status == .done }.count
            return count > 0 ? "\(count) done" : nil
        }
    }
}

// MARK: - Appearance

struct AppearanceSectionView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme").font(.system(size: 14)).foregroundStyle(store.colors.t2)
                        Text("\(store.theme.rawValue.capitalized) mode").font(.system(size: 11, design: .monospaced)).foregroundStyle(store.colors.t6)
                    }
                    Spacer()
                    Button {
                        store.toggleTheme()
                    } label: {
                        Text(store.theme == .dark ? "Light mode" : "Dark mode")
                            .font(.system(size: 12))
                            .foregroundStyle(store.colors.t3)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                Divider().overlay(store.colors.b0)

                Toggle(isOn: $store.commandPaletteGroupHeaders) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Command palette headers").font(.system(size: 14)).foregroundStyle(store.colors.t2)
                        Text("Show group labels in search results").font(.system(size: 11, design: .monospaced)).foregroundStyle(store.colors.t6)
                    }
                }
                .tint(store.colors.accent)
                .padding(.horizontal, 24).padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Labels

struct LabelsSectionView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingLabel: String?
    @State private var editValue = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        let labels = store.getAllLabels()
        ScrollView {
            if labels.isEmpty {
                Text("No labels yet. Use the label picker on any task to add one.")
                    .font(.system(size: 14))
                    .foregroundStyle(store.colors.t6)
                    .padding(24)
            } else {
                VStack(spacing: 0) {
                    ForEach(labels, id: \.self) { label in
                        HStack {
                            if editingLabel == label {
                                TextField("", text: $editValue)
                                    .textFieldStyle(.plain)
                                    .focused($fieldFocused)
                                    .reportsTextFocus(fieldFocused, to: store)
                                    .onSubmit { commitEdit() }
                            } else {
                                Text(label).font(.system(size: 14)).foregroundStyle(store.colors.t2)
                            }
                            Spacer()
                            Button("rename") { editingLabel = label; editValue = label; fieldFocused = true }
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(store.colors.t5)
                            Button("delete") { store.deleteLabel(label) }
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(store.colors.danger)
                        }
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        Divider().overlay(store.colors.b0)
                    }
                }
            }
        }
    }

    private func commitEdit() {
        if let old = editingLabel, !editValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.renameLabel(old, to: editValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        editingLabel = nil
    }
}

// MARK: - Views & Projects

struct ViewsSectionView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let splits = store.splits.filter(\.enabled).sorted { $0.sortOrder < $1.sortOrder }
        ScrollView {
            if splits.isEmpty {
                Text("No views yet. Create a project or filter from the command palette.")
                    .font(.system(size: 14))
                    .foregroundStyle(store.colors.t6)
                    .padding(24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(splits.enumerated()), id: \.element.id) { index, split in
                        HStack {
                            Text("\(index + 1)").font(.system(size: 10, design: .monospaced)).foregroundStyle(store.colors.t7).frame(width: 16)
                            Text(split.name).font(.system(size: 14)).foregroundStyle(store.colors.t2)
                            Spacer()
                            Button { store.moveSplit(split, dir: -1) } label: {
                                Image(systemName: "chevron.up").font(.system(size: 11)).foregroundStyle(store.colors.t6)
                            }
                            .buttonStyle(.plain).disabled(index == 0)
                            Button { store.moveSplit(split, dir: 1) } label: {
                                Image(systemName: "chevron.down").font(.system(size: 11)).foregroundStyle(store.colors.t6)
                            }
                            .buttonStyle(.plain).disabled(index == splits.count - 1)
                        }
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        Divider().overlay(store.colors.b0)
                    }
                    Text("g+1 through g+\(min(splits.count, 9)) to jump by keyboard")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(store.colors.t7)
                        .padding(.horizontal, 24).padding(.top, 10)

                    if splits.count > splitViewSoftLimit {
                        Text("You have \(splits.count) views. Keeping it to \(splitViewSoftLimit) or fewer tends to help with focus.")
                            .font(.system(size: 10))
                            .foregroundStyle(store.colors.t6)
                            .padding(12)
                            .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 24).padding(.top, 8)
                    }
                }
            }
        }
    }
}

// MARK: - Data

struct DataSectionView: View {
    @EnvironmentObject var store: AppStore
    @State private var confirming = false

    var body: some View {
        let doneCount = store.tasks.filter { $0.status == .done }.count
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear completed").font(.system(size: 14)).foregroundStyle(store.colors.t2)
                    Text("\(doneCount) task\(doneCount == 1 ? "" : "s") done").font(.system(size: 11, design: .monospaced)).foregroundStyle(store.colors.t6)
                }
                Spacer()
                Button(confirming ? "Confirm?" : "Clear") {
                    if !confirming { confirming = true; return }
                    let ids = Set(store.tasks.filter { $0.status == .done }.map(\.id))
                    if !ids.isEmpty { store.deleteBulkTasks(ids) }
                    confirming = false
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(confirming ? .white : store.colors.t3)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(confirming ? store.colors.danger : store.colors.btn, in: RoundedRectangle(cornerRadius: 6))
                .disabled(doneCount == 0)
            }
            if confirming {
                Text("Permanently deletes \(doneCount) task\(doneCount == 1 ? "" : "s"). Tap again to confirm.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(store.colors.danger)
            }
        }
        .padding(24)
    }
}
