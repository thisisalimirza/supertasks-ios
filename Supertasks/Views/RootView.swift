import SwiftUI

/// Below this width the detail panel becomes a full-screen overlay instead of a side panel —
/// same concept as NARROW_BREAKPOINT / useWindowWidth in the Mac app, sized up a bit since an
/// iPad in Split View still has more room than the Mac app's narrowest window.
private let narrowBreakpoint: CGFloat = 700
private let settingsWidth: CGFloat = 280
private let detailWidth: CGFloat = 420

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @State private var chord = ChordState()
    @FocusState private var rootFocused: Bool

    var body: some View {
        GeometryReader { geo in
            let isNarrow = geo.size.width <= narrowBreakpoint
            let settingsPanelWidth = min(settingsWidth, geo.size.width * 0.6)
            let detailPanelWidth = min(detailWidth, geo.size.width * 0.6)

            ZStack(alignment: .leading) {
                store.colors.bg.ignoresSafeArea()

                TaskListView()
                    .padding(.leading, store.isSettingsOpen ? settingsPanelWidth : 0)
                    .padding(.trailing, (store.isDetailOpen && !isNarrow) ? detailPanelWidth : 0)
                    .safeAreaInset(edge: .bottom) { StatusBarView() }

                if store.isSettingsOpen {
                    HStack(spacing: 0) {
                        SettingsPanelView()
                            .frame(width: settingsPanelWidth)
                        Spacer(minLength: 0)
                    }
                    .transition(.move(edge: .leading))
                    .zIndex(2)
                }

                if store.isDetailOpen {
                    if isNarrow {
                        TaskDetailView()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .transition(.move(edge: .trailing))
                            .zIndex(3)
                    } else {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            TaskDetailView()
                                .frame(width: detailPanelWidth)
                        }
                        .transition(.move(edge: .trailing))
                        .zIndex(2)
                    }
                }

                overlays
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea(.keyboard)
        .animation(.easeInOut(duration: 0.2), value: store.isSettingsOpen)
        .animation(.easeInOut(duration: 0.2), value: store.isDetailOpen)
        .preferredColorScheme(store.theme == .dark ? .dark : .light)
        .focusable()
        .focusEffectDisabled()
        .focused($rootFocused)
        .onKeyPress { press in handleGlobalKeyPress(press, store: store, chord: chord) }
        .onAppear { rootFocused = true }
        .onChange(of: store.isTextInputFocused) { _, focused in
            if !focused { rootFocused = true }
        }
    }

    @ViewBuilder private var overlays: some View {
        if store.isCommandPaletteOpen { CommandPaletteView().zIndex(50) }
        if store.isShortcutCheatsheetOpen { ShortcutCheatsheetView().zIndex(50) }
        if store.isProjectNavOpen { ProjectNavOverlayView().zIndex(50) }
        if store.isSplitEditorOpen { SplitEditorView(store: store).zIndex(50) }
        if store.isNewProjectOpen { NewProjectDialogView().zIndex(50) }
        if store.activePicker != nil { PickerDispatchView().zIndex(52) }

        ToastStackView().zIndex(60)

        if !store.onboardingCompleted {
            OnboardingView().zIndex(100)
        }
    }
}
