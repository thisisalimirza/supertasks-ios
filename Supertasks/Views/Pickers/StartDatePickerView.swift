import SwiftUI

struct StartDatePickerView: View {
    @EnvironmentObject var store: AppStore
    let task: TaskItem
    @State private var date: Date

    init(task: TaskItem) {
        self.task = task
        _date = State(initialValue: task.startDate ?? Calendar.current.startOfDay(for: .now))
    }

    var body: some View {
        OverlayCard(maxWidth: 380, onBackgroundTap: { store.closePicker() }) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hold until")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(store.colors.t1)
                    Text("Hidden from Inbox until this date")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(store.colors.t7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(store.colors.accent)

                HStack {
                    Button("Clear") {
                        store.mutate(task) { $0.startDate = nil }
                        store.closePicker()
                    }
                    .foregroundStyle(store.colors.danger)

                    Spacer()

                    Button("Set Hold Date") {
                        store.mutate(task) { $0.startDate = date }
                        store.closePicker()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.colors.accent)
                }
            }
            .padding(20)
        }
    }
}
