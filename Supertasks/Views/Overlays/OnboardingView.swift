import SwiftUI

private struct EssentialShortcut {
    let keys: [String]
    let label: String
}

private let essentialShortcuts: [EssentialShortcut] = [
    EssentialShortcut(keys: ["J", "K"], label: "Move between tasks"),
    EssentialShortcut(keys: ["→"], label: "Open task detail"),
    EssentialShortcut(keys: ["C"], label: "Create a task"),
    EssentialShortcut(keys: ["D"], label: "Mark done"),
    EssentialShortcut(keys: ["S"], label: "Star a task"),
    EssentialShortcut(keys: ["!"], label: "Cycle priority"),
    EssentialShortcut(keys: ["⌘K"], label: "Command palette"),
    EssentialShortcut(keys: ["Swipe / tap +"], label: "Works great with touch too"),
]

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @State private var step = 0
    @State private var withDemoData = false
    @State private var loading = false

    var body: some View {
        ZStack {
            store.colors.bg.ignoresSafeArea()

            VStack {
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .fill(i == step ? store.colors.accent : store.colors.b3)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 32)
                Spacer()
            }

            if step == 0 { welcomeStep } else { shortcutsStep }
        }
        .animation(.easeOut(duration: 0.2), value: step)
    }

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color(hex: 0x5B47E0), Color(hex: 0x8B5CF6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: Color(hex: 0x5B47E0).opacity(0.3), radius: 12, y: 6)
                Image(systemName: "checklist")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Welcome to Supertasks")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(store.colors.t1)
                Text("A keyboard-first task manager, built for iPad.\nHow would you like to start?")
                    .font(.system(size: 14))
                    .foregroundStyle(store.colors.t5)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                choiceCard(icon: "✦", title: "Fresh start", subtitle: "Empty inbox, ready to go") {
                    withDemoData = false
                    step = 1
                }
                choiceCard(icon: "◈", title: "Try with sample data", subtitle: "Pre-filled tasks to explore") {
                    withDemoData = true
                    step = 1
                }
            }
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 32)
    }

    private func choiceCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(icon).font(.system(size: 22))
                VStack(spacing: 4) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(store.colors.t2)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(store.colors.t6).multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24).padding(.horizontal, 12)
            .background(store.colors.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(store.colors.b2, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var shortcutsStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Built for the keyboard")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(store.colors.t1)
                Text("You can do everything without touching the keyboard too — here are the essentials:")
                    .font(.system(size: 14))
                    .foregroundStyle(store.colors.t5)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                ForEach(essentialShortcuts, id: \.label) { item in
                    HStack {
                        Text(item.label).font(.system(size: 14)).foregroundStyle(store.colors.t4)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(item.keys, id: \.self) { key in
                                Text(key)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(store.colors.t1)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 5))
                                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(store.colors.b3))
                            }
                        }
                    }
                }
            }

            Text("Press ⌘/ anytime to see all shortcuts")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(store.colors.t7)

            Button {
                guard !loading else { return }
                loading = true
                store.completeOnboarding(withDemoData: withDemoData)
            } label: {
                Text(loading ? "Setting up…" : "Get started →")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(store.colors.accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(loading)
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 32)
    }
}
