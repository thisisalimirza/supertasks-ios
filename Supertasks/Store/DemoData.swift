import Foundation
import SwiftData

/// Port of seedDemoData() in the Mac app's database.ts — same tasks, same copy, so the
/// onboarding experience matches across platforms.
enum DemoData {
    static func seed(context: ModelContext) {
        let now = Date()
        func daysFromNow(_ n: Int) -> Date {
            let date = Calendar.current.date(byAdding: .day, value: n, to: now) ?? now
            return Calendar.current.startOfDay(for: date)
        }

        let work = Project(name: "Work", createdAt: now)
        let personal = Project(name: "Personal", createdAt: now)
        context.insert(work)
        context.insert(personal)

        let workSplit = Split(
            name: "Work",
            rules: SplitRules(projects: ["Work"]),
            ruleOperator: .AND,
            enabled: true,
            sortOrder: 0,
            createdAt: now
        )
        context.insert(workSplit)

        struct Seed {
            let title: String
            let notes: String
            let priority: TaskPriority
            let dueDate: Date?
            let project: String
            let starred: Bool
            let sortOrder: Double
            let status: TaskStatus
            let completedAt: Date?
        }

        let seeds: [Seed] = [
            // Inbox
            Seed(title: "Welcome — navigate with J and K",
                 notes: "Use J and K to move between tasks without touching the mouse.\n\nTap a task or press → / Enter to open the detail panel. Press ← to close it.\n\nTap + or press C to create a new task.",
                 priority: .none, dueDate: nil, project: "", starred: true, sortOrder: 110, status: .inbox, completedAt: nil),
            Seed(title: "Try starring, prioritising, and assigning a project",
                 notes: "With a task selected:\n\n  S — star / unstar\n  ! — cycle priority\n  M — assign to a project\n  R — set a due date\n  L — add a label\n\nAll of these are also editable in the detail panel, or with a long-press.",
                 priority: .none, dueDate: nil, project: "", starred: false, sortOrder: 100, status: .inbox, completedAt: nil),
            Seed(title: "Complete a task and use the command palette",
                 notes: "Press D to mark a task done. It will slide away — check the Done view to find it again.\n\nPress ⌘K (hardware keyboard) to open the command palette and jump anywhere instantly.",
                 priority: .none, dueDate: nil, project: "", starred: false, sortOrder: 90, status: .inbox, completedAt: nil),
            Seed(title: "Review Q1 goals and update OKRs",
                 notes: "Pull latest numbers from the dashboard before the all-hands on Friday. Focus on eng velocity and customer retention metrics.",
                 priority: .high, dueDate: daysFromNow(1), project: "", starred: true, sortOrder: 80, status: .inbox, completedAt: nil),
            Seed(title: "Submit expense report for last month",
                 notes: "Receipts are in the Receipts folder in Google Drive. Conference hotel, team dinner on the 14th, and two Uber rides.",
                 priority: .medium, dueDate: daysFromNow(3), project: "", starred: false, sortOrder: 70, status: .inbox, completedAt: nil),
            // Work
            Seed(title: "Ship v2 release to production",
                 notes: "Checklist before deploying:\n- Green CI on main branch\n- Design sign-off on new onboarding flow\n- QA smoke test on staging\n- Update changelog and bump version\n- Notify #releases in Slack after deploy\n\nRollback plan: feature flag is already in place, flip it off if error rate spikes.",
                 priority: .urgent, dueDate: daysFromNow(2), project: "Work", starred: true, sortOrder: 100, status: .inbox, completedAt: nil),
            Seed(title: "Review open pull requests",
                 notes: "Three PRs waiting:\n- Auth refactor (Tyler) — needs careful review, touches session handling\n- Dashboard perf fix (Sara) — quick pass, looks good from the diff\n- Docs update (auto) — approve and merge\n\nTip: press ⌘J / ⌘K to reorder tasks by priority.",
                 priority: .high, dueDate: daysFromNow(0), project: "Work", starred: false, sortOrder: 90, status: .inbox, completedAt: nil),
            Seed(title: "Write project retrospective doc",
                 notes: "Cover: what shipped, what slipped, three things to do differently. Keep it under two pages — people actually read short retros.\n\nTemplate is in Notion under Engineering > Retros.",
                 priority: .medium, dueDate: daysFromNow(5), project: "Work", starred: false, sortOrder: 80, status: .inbox, completedAt: nil),
            Seed(title: "Update product roadmap for next quarter",
                 notes: "Sync with design and support first to capture the top user pain points. The roadmap lives in Notion — share the link in #product once updated.",
                 priority: .low, dueDate: nil, project: "Work", starred: false, sortOrder: 70, status: .inbox, completedAt: nil),
            // Personal
            Seed(title: "Read Atomic Habits",
                 notes: "Currently on chapter 5. The core idea so far: you don't rise to the level of your goals, you fall to the level of your systems.\n\nWant to finish by end of the month.",
                 priority: .none, dueDate: nil, project: "Personal", starred: true, sortOrder: 100, status: .inbox, completedAt: nil),
            Seed(title: "Plan weekend trip",
                 notes: "Options: Ojai, Big Bear, or Santa Barbara. Check Airbnb for availability. Budget around $300 for two nights.",
                 priority: .low, dueDate: daysFromNow(7), project: "Personal", starred: false, sortOrder: 90, status: .inbox, completedAt: nil),
            Seed(title: "Book dentist appointment",
                 notes: "It's been way too long. Call Dr. Patel's office — number is in contacts.",
                 priority: .none, dueDate: nil, project: "Personal", starred: false, sortOrder: 80, status: .inbox, completedAt: nil),
            // Done (so the Done view isn't empty on first open)
            Seed(title: "Set up Supertasks", notes: "", priority: .none, dueDate: nil, project: "", starred: false, sortOrder: 0, status: .done, completedAt: now),
        ]

        for seed in seeds {
            let task = TaskItem(
                title: seed.title, notes: seed.notes, status: seed.status, priority: seed.priority,
                dueDate: seed.dueDate, project: seed.project, createdAt: now, completedAt: seed.completedAt,
                starred: seed.starred, sortOrder: seed.sortOrder
            )
            context.insert(task)
        }

        try? context.save()
    }
}
