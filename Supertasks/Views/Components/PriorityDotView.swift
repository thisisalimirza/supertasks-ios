import SwiftUI

/// Small colored dot indicating priority — same palette as PriorityDot.tsx (intentionally a
/// slightly different yellow for `.medium` than the priority pill in the detail header, matching
/// the Mac app's own inconsistency between TaskRow and TaskDetail).
private let rowPriorityColors: [TaskPriority: Color] = [
    .low: Color(hex: 0x5B6AFF),
    .medium: Color(hex: 0xFFD700),
    .high: Color(hex: 0xFF8C00),
    .urgent: Color(hex: 0xFF4444),
]

struct PriorityDotView: View {
    let priority: TaskPriority
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(rowPriorityColors[priority] ?? .clear)
            .frame(width: size, height: size)
            .shadow(color: (rowPriorityColors[priority] ?? .clear).opacity(0.4), radius: 3)
            .animation(.easeOut(duration: 0.15), value: priority)
    }
}
