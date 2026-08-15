import SwiftUI
import SwiftData

@main
struct SupertasksApp: App {
    let container: ModelContainer
    @StateObject private var store: AppStore

    init() {
        let schema = Schema([TaskItem.self, Project.self, Split.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.container = container
        _store = StateObject(wrappedValue: AppStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .modelContainer(container)
        }
    }
}
