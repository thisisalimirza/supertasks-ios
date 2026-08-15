import SwiftUI

/// Resolves `store.activePicker` + `store.pickerTaskID` to the right picker card. Rendered
/// once, centrally, by RootView — same task the Mac app's inline row pickers do, adapted to a
/// touch-friendly modal.
struct PickerDispatchView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        if let kind = store.activePicker,
           let taskID = store.pickerTaskID,
           let task = store.tasks.first(where: { $0.id == taskID }) {
            switch kind {
            case .due: DueDatePickerView(task: task)
            case .startDate: StartDatePickerView(task: task)
            case .label: LabelPickerView(task: task)
            case .project: ProjectPickerView(task: task)
            }
        }
    }
}
