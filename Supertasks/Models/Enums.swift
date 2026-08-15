import Foundation

enum TaskStatus: String, Codable, CaseIterable, Hashable {
    case inbox
    case done
    case archived
}

enum TaskPriority: String, Codable, CaseIterable, Hashable {
    case none
    case low
    case medium
    case high
    case urgent

    /// none -> low -> medium -> high -> urgent -> none
    var next: TaskPriority {
        let cycle = TaskPriority.cycle
        let idx = cycle.firstIndex(of: self) ?? 0
        return cycle[(idx + 1) % cycle.count]
    }

    static let cycle: [TaskPriority] = [.none, .low, .medium, .high, .urgent]

    var displayName: String {
        switch self {
        case .none: return "No priority"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}

enum RuleOperator: String, Codable, CaseIterable, Hashable {
    case AND
    case OR
}

/// Views the app can be showing. Mirrors `TaskView` in the Mac app's shared/types.ts.
/// `.project` and `.split` carry their target via AppStore.selectedProject / activeSplitID.
enum TaskViewKind: String, Codable, Hashable {
    case inbox
    case today
    case tomorrow
    case week
    case all
    case done
    case project
    case split
    case upcoming
}

/// Which inline picker is currently active for the selected task.
enum PickerKind: String, Hashable {
    case due
    case startDate
    case label
    case project
}

/// Which settings section is showing (nil = root menu).
enum SettingsSection: String, CaseIterable, Hashable {
    case appearance
    case labels
    case views
    case data

    var title: String {
        switch self {
        case .appearance: return "Appearance"
        case .labels: return "Labels"
        case .views: return "Views & Projects"
        case .data: return "Data"
        }
    }
}
