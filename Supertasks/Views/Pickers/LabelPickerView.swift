import SwiftUI

struct LabelPickerView: View {
    @EnvironmentObject var store: AppStore
    let task: TaskItem
    @State private var newLabel = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        OverlayCard(maxWidth: 420, onBackgroundTap: { store.closePicker() }) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Labels")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.colors.t1)

                HStack {
                    TextField("New label…", text: $newLabel)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($fieldFocused)
                        .reportsTextFocus(fieldFocused, to: store)
                        .onSubmit(addLabel)
                    Button("Add", action: addLabel)
                        .disabled(newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(10)
                .background(store.colors.btn, in: RoundedRectangle(cornerRadius: 8))

                if store.getAllLabels().isEmpty {
                    Text("No labels yet — add one above.")
                        .font(.system(size: 12))
                        .foregroundStyle(store.colors.t6)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(store.getAllLabels(), id: \.self) { label in
                                let isOn = task.labels.contains(label)
                                Button {
                                    store.toggleLabel(task, label: label)
                                } label: {
                                    HStack {
                                        Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(isOn ? store.colors.accent : store.colors.t6)
                                        Text(label).foregroundStyle(store.colors.t2)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }

                Button("Done") { store.closePicker() }
                    .buttonStyle(.borderedProminent)
                    .tint(store.colors.accent)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    private func addLabel() {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !task.labels.contains(trimmed) { store.toggleLabel(task, label: trimmed) }
        newLabel = ""
    }
}
