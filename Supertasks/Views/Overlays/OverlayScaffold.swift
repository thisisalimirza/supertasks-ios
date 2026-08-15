import SwiftUI

/// Shared "dimmed backdrop + centered card" chrome used by the command palette, project nav,
/// split editor, new-project dialog, and pickers — the touch equivalent of the Mac app's
/// `fixed inset-0 z-50` overlay pattern.
struct OverlayCard<Content: View>: View {
    @EnvironmentObject var store: AppStore
    var maxWidth: CGFloat = 520
    var topPadding: CGFloat = 90
    var onBackgroundTap: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onBackgroundTap?() }

            content
                .frame(maxWidth: maxWidth)
                .background(store.colors.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(store.colors.b2))
                .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
                .padding(.horizontal, 24)
                .padding(.top, topPadding)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
