import SwiftUI
import SwiftData

struct EventEditView: View {

    let rabbit: Rabbit

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var type = EventType.hospital
    @State private var date = Date()
    @State private var title = ""
    @State private var memo = ""
    @State private var photo: Data?

    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("できごと") {
                    Picker("種類", selection: $type) {
                        ForEach(EventType.allCases) { eventType in
                            Label(eventType.label, systemImage: eventType.symbolName).tag(eventType)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    DatePicker("日付", selection: $date, in: ...Date(), displayedComponents: .date)

                    if type == .other {
                        TextField("タイトル", text: $title)
                    }
                }

                Section("写真") {
                    PhotoField(label: "写真を選ぶ", data: $photo)
                }

                Section("メモ") {
                    TextField("メモ（任意）", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if type == .moltStart || type == .moltEnd {
                    Section {
                        Text("換毛の開始と終了を記録すると、去年の同じ時期との比較ができるようになります。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("イベント登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
        }
        .alert("保存できませんでした", isPresented: $showError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        do {
            let repository = EventRepository(context: context)
            repository.create(
                for: rabbit,
                date: date.startOfDayRL,
                type: type,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
                photo: photo
            )
            try context.save()

            // 換毛開始などは「最近の変化」に効くため、今日の差分を作り直す。
            let service = DifferenceService(context: context)
            try service.regenerate(for: rabbit, on: Date())
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return
        }

        dismiss()
    }
}
