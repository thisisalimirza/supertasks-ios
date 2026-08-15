import SwiftUI

struct EmptyStateConfig {
    let heading: String
    var subheading: String?
    var showGreeting: Bool = false
    var actionLabel: String?
}

/// Per-view empty-state copy. Port of getEmptyConfig() in TaskList.tsx.
func emptyConfig(for view: TaskViewKind, activeSplit: Split?, selectedProject: String?) -> EmptyStateConfig {
    switch view {
    case .inbox: return EmptyStateConfig(heading: "You're all done", showGreeting: true)
    case .today: return EmptyStateConfig(heading: "Clear for today", showGreeting: true)
    case .tomorrow: return EmptyStateConfig(heading: "Nothing due tomorrow", subheading: "Tasks with a due date of tomorrow will appear here")
    case .week: return EmptyStateConfig(heading: "Clear this week", subheading: "Tasks due in the next 7 days will appear here", showGreeting: true)
    case .upcoming: return EmptyStateConfig(heading: "Nothing upcoming", subheading: "Hold a task with H to schedule it ahead")
    case .all: return EmptyStateConfig(heading: "All clear", subheading: "Tap + to create your first task")
    case .done: return EmptyStateConfig(heading: "Nothing completed", subheading: "Completed tasks will appear here")
    case .split:
        if let split = activeSplit {
            return EmptyStateConfig(heading: "\(split.name) is empty", subheading: "No tasks match these filters", actionLabel: "Edit Split")
        }
        return EmptyStateConfig(heading: "Nothing here", subheading: "Tap + to create a task")
    case .project:
        if let name = selectedProject {
            return EmptyStateConfig(heading: name, subheading: "No tasks in this project yet · tap + to add one")
        }
        return EmptyStateConfig(heading: "Nothing here", subheading: "Tap + to create a task")
    }
}

private func greeting() -> String {
    let h = Calendar.current.component(.hour, from: .now)
    switch h {
    case 0..<5: return "Burning the midnight oil"
    case 5..<12: return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<21: return "Good evening"
    default: return "Winding down"
    }
}

/// Full-bleed "empty" backdrop shown whenever the current view has no tasks — a soft gradient
/// with a time-aware greeting, replacing the Mac app's InboxZeroScreen (which hotlinks a random
/// photo from picsum.photos; skipped here so the app stays fully offline).
struct EmptyStateView: View {
    @EnvironmentObject var store: AppStore
    let config: EmptyStateConfig

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [store.colors.elevated, store.colors.bg, store.colors.panel],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .center)

            VStack(spacing: 12) {
                Spacer()
                VStack(spacing: 12) {
                    if config.showGreeting {
                        Text(greeting().uppercased())
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Text(config.heading)
                        .font(.system(size: 32, weight: .light))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if let subheading = config.subheading {
                        Text(subheading)
                            .font(.system(size: 12, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    } else {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.system(size: 11, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 32)
                Spacer().frame(height: 96)
            }
        }
        .ignoresSafeArea()
    }
}
