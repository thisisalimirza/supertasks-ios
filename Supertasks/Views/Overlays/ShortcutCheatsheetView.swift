import SwiftUI

private struct GChordEntry {
    let key: String
    let description: String
}

private let gChordEntries: [GChordEntry] = [
    GChordEntry(key: "I", description: "Go to Inbox"),
    GChordEntry(key: "A", description: "Go to All Tasks"),
    GChordEntry(key: "D", description: "Go to Done"),
    GChordEntry(key: "T", description: "Go to Today"),
    GChordEntry(key: "N", description: "Go to Tomorrow"),
    GChordEntry(key: "W", description: "Go to This Week"),
    GChordEntry(key: "P", description: "Go to Project…"),
]

struct ShortcutCheatsheetView: View {
    @EnvironmentObject var store: AppStore

    private var groups: [(String, [ShortcutDef])] {
        var order: [String] = []
        var dict: [String: [ShortcutDef]] = [:]
        for s in ShortcutCatalog.all {
            if dict[s.group] == nil { order.append(s.group) }
            dict[s.group, default: []].append(s)
        }
        return order.map { ($0, dict[$0] ?? []) }
    }

    var body: some View {
        OverlayCard(maxWidth: 720, topPadding: 60, onBackgroundTap: { store.isShortcutCheatsheetOpen = false }) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Keyboard Shortcuts").font(.system(size: 17, weight: .semibold)).foregroundStyle(store.colors.t1)
                    Spacer()
                    Button("⌘/ to close") { store.isShortcutCheatsheetOpen = false }
                        .font(.system(size: 12))
                        .foregroundStyle(store.colors.t6)
                        .buttonStyle(.plain)
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], alignment: .leading, spacing: 20) {
                        ForEach(groups, id: \.0) { group, shortcuts in
                            column(title: group) {
                                ForEach(shortcuts) { s in
                                    shortcutLine(s.description, s.keyLabel)
                                }
                            }
                        }

                        column(title: "Go To (G + key)") {
                            ForEach(gChordEntries, id: \.key) { entry in
                                shortcutLine(entry.description, "G → \(entry.key)")
                            }
                        }

                        column(title: "Appearance") {
                            shortcutLine("Toggle light / dark mode", "⌘⇧L")
                        }
                    }
                }
                .frame(maxHeight: 480)
            }
            .padding(28)
        }
    }

    private func column<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(store.colors.t6)
            VStack(alignment: .leading, spacing: 8) { content() }
        }
    }

    private func shortcutLine(_ description: String, _ key: String) -> some View {
        HStack {
            Text(description).font(.system(size: 13)).foregroundStyle(store.colors.t4)
            Spacer()
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(store.colors.t1)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(store.colors.b3))
        }
    }
}
