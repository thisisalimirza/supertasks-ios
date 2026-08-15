import Foundation
import SwiftData

/// A single task. Mirrors the `Task` interface in the Mac app's shared/types.ts.
@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var status: TaskStatus
    var priority: TaskPriority
    var dueDate: Date?
    /// Hide the task from Inbox until this date ("hold until").
    var startDate: Date?
    var reminder: Date?
    /// Project name (empty string = unassigned). Projects are matched by name, not id,
    /// same as the Mac app.
    var project: String
    var labels: [String]
    var createdAt: Date
    var completedAt: Date?
    var starred: Bool
    /// Higher sortOrder = appears first within a view. Reassigned on manual reorder.
    var sortOrder: Double

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        status: TaskStatus = .inbox,
        priority: TaskPriority = .none,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        reminder: Date? = nil,
        project: String = "",
        labels: [String] = [],
        createdAt: Date = .now,
        completedAt: Date? = nil,
        starred: Bool = false,
        sortOrder: Double = Date.now.timeIntervalSince1970
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.startDate = startDate
        self.reminder = reminder
        self.project = project
        self.labels = labels
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.starred = starred
        self.sortOrder = sortOrder
    }

    /// True when startDate is set and is in the future — task should be hidden from Inbox/Today/etc.
    var hasUpcomingStart: Bool {
        guard let startDate else { return false }
        return Calendar.current.startOfDay(for: startDate) > Calendar.current.startOfDay(for: .now)
    }
}
