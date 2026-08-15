import SwiftUI

struct DueDatePickerView: View {
    @EnvironmentObject var store: AppStore
    let task: TaskItem
    @State private var date: Date

    init(task: TaskItem) {
        self.task = task
        _date = State(initialValue: task.dueDate ?? Calendar.current.startOfDay(for: .now))
    }

    var body: some View {
        OverlayCard(maxWidth: 380, onBackgroundTap: { store.closePicker() }) {
            VStack(spacing: 16) {
                Text("Due date")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.colors.t1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(store.colors.accent)

                HStack {
                    Button("Clear") {
                        store.mutate(task) { $0.dueDate = nil }
                        store.closePicker()
                    }
                    .foregroundStyle(store.colors.danger)

                    Spacer()

                    Button("Set Due Date") {
                        store.mutate(task) { $0.dueDate = date }
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
