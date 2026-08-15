import Foundation
import SwiftData

/// Filter rules for a Split (smart view). All non-empty/non-nil fields are combined
/// with `ruleOperator`. Mirrors `SplitRules` in the Mac app's shared/types.ts.
struct SplitRules: Codable, Equatable {
    var projects: [String] = []
    var labels: [String] = []
    var priorities: [TaskPriority] = []
    var dueBefore: Date?
    var dueAfter: Date?
    /// nil = ignore starred state entirely.
    var starred: Bool?

    var isEmpty: Bool {
        projects.isEmpty && labels.isEmpty && priorities.isEmpty
            && dueBefore == nil && dueAfter == nil && starred == nil
    }
}

/// A user-defined smart filter / view tab. Mirrors `Split` in shared/types.ts.
@Model
final class Split {
    @Attribute(.unique) var id: UUID
    var name: String
    var rules: SplitRules
    var ruleOperator: RuleOperator
    var enabled: Bool
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        rules: SplitRules = SplitRules(),
        ruleOperator: RuleOperator = .AND,
        enabled: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.rules = rules
        self.ruleOperator = ruleOperator
        self.enabled = enabled
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    /// True when this split's rules amount to "this project" and nothing else —
    /// i.e. it was auto-created when a task was first assigned to that project.
    func isProjectView(named projectName: String) -> Bool {
        rules.projects == [projectName]
            && rules.labels.isEmpty
            && rules.priorities.isEmpty
            && rules.starred == nil
            && rules.dueBefore == nil
            && rules.dueAfter == nil
            && name == projectName
    }
}
