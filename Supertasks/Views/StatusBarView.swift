import SwiftUI

private let viewModeLabels: [TaskViewKind: String] = [
    .inbox: "INBOX", .today: "TODAY", .tomorrow: "TOMORROW", .week: "THIS WEEK",
    .upcoming: "UPCOMING", .all: "ALL", .done: "DONE",
]

struct StatusBarView: View {
    @EnvironmentObject var store: AppStore

    private var tasks: [TaskItem] { store.getVisibleTasks() }
    private var incomplete: Int { tasks.filter { $0.status != .done }.count }
    private var activeSplit: Split? {
        store.activeView == .split ? store.splits.first { $0.id == store.activeSplitID } : nil
    }
    private var isPhotoMode: Bool { tasks.isEmpty && !store.isCreating }

    private var modeLabel: String {
        if let split = activeSplit { return "◉ \(split.name.uppercased())" }
        if store.activeView == .project, let name = store.selectedProject { return "◈ \(name.uppercased())" }
        return viewModeLabels[store.activeView] ?? store.activeView.rawValue.uppercased()
    }

    private var hints: [String] {
        if !store.selectedTaskIDs.isEmpty {
            return ["⌘D done", "⌘⌫ delete", "R due · H hold · L labels · M project", "Esc deselect"]
        }
        switch store.activePicker {
        case .due: return ["Tap to select", "Esc cancel"]
        case .label: return ["Tap to toggle", "Esc cancel"]
        case .project: return ["Tap to select", "Esc cancel"]
        case .startDate: return ["Tap to select", "Esc cancel"]
        case nil: return ["＋ new", "Tap to open", "⌘K palette"]
        }
    }

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Text(modeLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(isPhotoMode ? .white.opacity(0.6) : store.colors.accent)
                Text("\(incomplete) remaining")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isPhotoMode ? .white.opacity(0.35) : store.colors.t8)
                if !store.selectedTaskIDs.isEmpty {
                    Text("\(store.selectedTaskIDs.count) selected")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(isPhotoMode ? .white.opacity(0.6) : store.colors.accent)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                ForEach(hints, id: \.self) { hint in
                    Text(hint)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(isPhotoMode ? .white.opacity(0.35) : store.colors.t8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            Group {
                if isPhotoMode {
                    LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .top)
                } else {
                    store.colors.bg
                }
            }
        )
        .overlay(alignment: .top) {
            if !isPhotoMode {
                Rectangle().fill(store.colors.b1).frame(height: 1)
            }
        }
    }
}
