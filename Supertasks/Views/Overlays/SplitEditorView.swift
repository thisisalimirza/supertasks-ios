import SwiftUI

let splitViewSoftLimit = 5

private enum ConditionField: String, CaseIterable {
    case project, label, priority, starred, dueBefore, dueAfter

    var label: String {
        switch self {
        case .project: return "Project"
        case .label: return "Label"
        case .priority: return "Priority"
        case .starred: return "Starred"
        case .dueBefore: return "Due before"
        case .dueAfter: return "Due after"
        }
    }
}

private struct ConditionRow: Identifiable {
    let id = UUID()
    var field: ConditionField
    var textValue: String = ""
    var priority: TaskPriority = .urgent
    var starred: Bool = true
    var date: Date = Calendar.current.startOfDay(for: .now)
}

private func rulesToRows(_ rules: SplitRules) -> [ConditionRow] {
    var rows: [ConditionRow] = []
    rows.append(contentsOf: rules.projects.map { ConditionRow(field: .project, textValue: $0) })
    rows.append(contentsOf: rules.labels.map { ConditionRow(field: .label, textValue: $0) })
    rows.append(contentsOf: rules.priorities.map { ConditionRow(field: .priority, priority: $0) })
    if let d = rules.dueBefore { rows.append(ConditionRow(field: .dueBefore, date: d)) }
    if let d = rules.dueAfter { rows.append(ConditionRow(field: .dueAfter, date: d)) }
    if let s = rules.starred { rows.append(ConditionRow(field: .starred, starred: s)) }
    return rows.isEmpty ? [ConditionRow(field: .priority)] : rows
}

private func rowsToRules(_ rows: [ConditionRow]) -> SplitRules {
    SplitRules(
        projects: rows.filter { $0.field == .project && !$0.textValue.trimmingCharacters(in: .whitespaces).isEmpty }.map(\.textValue),
        labels: rows.filter { $0.field == .label && !$0.textValue.trimmingCharacters(in: .whitespaces).isEmpty }.map(\.textValue),
        priorities: rows.filter { $0.field == .priority }.map(\.priority),
        dueBefore: rows.first { $0.field == .dueBefore }?.date,
        dueAfter: rows.first { $0.field == .dueAfter }?.date,
        starred: rows.first { $0.field == .starred }?.starred
    )
}

struct SplitEditorView: View {
    @EnvironmentObject var store: AppStore
    @State private var name: String
    @State private var conditions: [ConditionRow]
    @State private var operatorValue: RuleOperator
    @FocusState private var nameFocused: Bool

    private let editingSplit: Split?
    private let isFilter: Bool
    private let overLimit: Bool

    init(store: AppStore) {
        let split = store.editingSplitID.flatMap { id in store.splits.first { $0.id == id } }
        self.editingSplit = split
        self.isFilter = store.splitEditorIntent == .filter && split == nil
        self.overLimit = split == nil && store.splits.filter(\.enabled).count >= splitViewSoftLimit
        _name = State(initialValue: split?.name ?? "")
        _conditions = State(initialValue: split.map { rulesToRows($0.rules) } ?? [ConditionRow(field: .priority)])
        _operatorValue = State(initialValue: split?.ruleOperator ?? .AND)
    }

    private func close() { store.isSplitEditorOpen = false }

    var body: some View {
        OverlayCard(maxWidth: 540, topPadding: 70, onBackgroundTap: close) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                Divider().overlay(store.colors.b1)
                rulesSection
                Divider().overlay(store.colors.b1)
                footerSection
            }
        }
        .onAppear {
            if !isFilter { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { nameFocused = true } }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editingSplit != nil ? "Edit View" : (isFilter ? "Filter Tasks" : "New View"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(store.colors.t1)

            if !isFilter {
                TextField("Name (e.g. Urgent, Work, Waiting)", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($nameFocused)
                    .reportsTextFocus(nameFocused, to: store)
                    .padding(10)
                    .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 8))
            }

            if overLimit {
                Text("You already have \(store.splits.filter(\.enabled).count) views. More than \(splitViewSoftLimit) can fragment your focus — consider consolidating before adding more.")
                    .font(.system(size: 10))
                    .foregroundStyle(store.colors.t6)
            }
        }
        .padding(20)
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FILTER RULES")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(store.colors.t7)
                Spacer()
                if conditions.count > 1 {
                    Picker("", selection: $operatorValue) {
                        Text("AND").tag(RuleOperator.AND)
                        Text("OR").tag(RuleOperator.OR)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }

            ForEach($conditions) { $row in
                conditionRowView($row)
            }

            Button {
                conditions.append(ConditionRow(field: .priority))
            } label: {
                Label("Add rule", systemImage: "plus.circle").font(.system(size: 12)).foregroundStyle(store.colors.t6)
            }
            .buttonStyle(.plain)

            if conditions.isEmpty {
                Text("⚠ No rules — this view will show all tasks")
                    .font(.system(size: 10))
                    .foregroundStyle(store.colors.warn)
            }
        }
        .padding(20)
    }

    private func conditionRowView(_ row: Binding<ConditionRow>) -> some View {
        HStack(spacing: 8) {
            Picker("", selection: row.field) {
                ForEach(ConditionField.allCases, id: \.self) { field in
                    Text(field.label).tag(field)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 12))

            switch row.wrappedValue.field {
            case .priority:
                Picker("", selection: row.priority) {
                    ForEach(TaskPriority.cycle.reversed(), id: \.self) { p in
                        Text(p.rawValue.capitalized).tag(p)
                    }
                }
                .pickerStyle(.menu)
            case .starred:
                Picker("", selection: row.starred) {
                    Text("Starred only").tag(true)
                    Text("Unstarred only").tag(false)
                }
                .pickerStyle(.menu)
            case .dueBefore, .dueAfter:
                DatePicker("", selection: row.date, displayedComponents: .date)
                    .labelsHidden()
            case .project:
                TextField("Project name", text: row.textValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(6)
                    .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 6))
            case .label:
                TextField("Label name", text: row.textValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(6)
                    .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 6))
            }

            Spacer(minLength: 0)

            Button {
                conditions.removeAll { $0.id == row.wrappedValue.id }
            } label: {
                Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(store.colors.t7)
            }
            .buttonStyle(.plain)
        }
    }

    private var footerSection: some View {
        HStack {
            Button("Cancel", action: close)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(store.colors.t6)

            if let editingSplit {
                Button("Delete") {
                    store.deleteSplit(editingSplit)
                    close()
                }
                .font(.system(size: 12))
                .foregroundStyle(store.colors.danger)
            }

            Spacer()

            Button(editingSplit != nil ? "Save Changes" : (isFilter ? "Apply Filter" : "Create View")) {
                save()
            }
            .buttonStyle(.borderedProminent)
            .tint(store.colors.accent)
        }
        .padding(20)
    }

    private func rowValueDisplay(_ row: ConditionRow) -> String {
        switch row.field {
        case .project, .label: return row.textValue
        default: return ""
        }
    }

    private func save() {
        var rules = rowsToRules(conditions)
        var trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if isFilter && trimmedName.isEmpty {
            if let first = conditions.first {
                let value = rowValueDisplay(first)
                trimmedName = value.isEmpty ? first.field.label : "\(first.field.label): \(value)"
            } else {
                trimmedName = "Filter"
            }
        }
        guard !trimmedName.isEmpty else { nameFocused = true; return }

        if let old = editingSplit {
            let isProjectView = old.isProjectView(named: old.name)
            let oldProjectName = isProjectView ? old.rules.projects.first : nil

            var newProjectName: String?
            if let oldProjectName, rules.projects.count == 1, rules.projects[0] != oldProjectName {
                newProjectName = rules.projects[0]
            } else if let oldProjectName, trimmedName != oldProjectName {
                newProjectName = trimmedName
            }

            if let oldProjectName, let newProjectName {
                store.renameProject(oldProjectName, to: newProjectName)
                if rules.projects.isEmpty || rules.projects[0] == oldProjectName {
                    rules.projects = [newProjectName]
                }
            }

            store.updateSplit(old) { $0.name = trimmedName; $0.rules = rules; $0.ruleOperator = operatorValue }
        } else {
            let split = store.createSplit(name: trimmedName, rules: rules, ruleOperator: operatorValue, enabled: true)
            store.setActiveSplit(split.id)
        }
        close()
    }
}
