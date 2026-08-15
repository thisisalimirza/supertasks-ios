import SwiftUI

private let toastDuration: TimeInterval = 3.5

private struct ToastRow: View {
    @EnvironmentObject var store: AppStore
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Text(toast.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(store.colors.t3)
                .lineLimit(1)
            if toast.undoID != nil {
                Button("Undo") {
                    store.dismissToast(toast.id)
                    store.undo()
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(store.colors.accent)
                .buttonStyle(.plain)
            }
            Button {
                store.dismissToast(toast.id)
            } label: {
                Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(store.colors.t7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(width: 260, alignment: .leading)
        .background(store.colors.elevated, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(store.colors.b2))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .task(id: toast.id) {
            try? await _Concurrency.Task.sleep(nanoseconds: UInt64(toastDuration * 1_000_000_000))
            store.dismissToast(toast.id)
        }
    }
}

struct ToastStackView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    ForEach(store.toasts) { toast in
                        ToastRow(toast: toast)
                    }
                }
            }
        }
        .padding(.trailing, 24)
        .padding(.bottom, 56)
        .allowsHitTesting(!store.toasts.isEmpty)
    }
}
