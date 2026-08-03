import SwiftUI
import SwiftData

/// 初回セットアップと2羽目以降の追加で、同じ入力欄を使うための下書き。
struct RabbitDraft {

    var name = ""
    var breed = ""
    var sex = Sex.unknown
    var hasBirthday = false
    var birthday = Date()
    var hasAdoptionDate = false
    var adoptionDate = Date()
    var photo: Data?

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool { !trimmedName.isEmpty }

    /// うさぎ本体と、誕生日・お迎え日のイベントをまとめて挿入する。
    /// 呼び出し側で context.save() すること（失敗時に rollback できるようにするため）。
    @discardableResult
    func insert(into context: ModelContext) -> Rabbit {
        let rabbit = RabbitRepository(context: context).create(
            name: trimmedName,
            birthday: hasBirthday ? birthday : nil,
            adoptionDate: hasAdoptionDate ? adoptionDate : nil,
            breed: breed.trimmingCharacters(in: .whitespacesAndNewlines),
            sex: sex,
            photo: photo
        )

        // 誕生日・お迎え日はタイムラインにも残す。
        let eventRepository = EventRepository(context: context)
        if hasBirthday {
            eventRepository.create(for: rabbit, date: birthday, type: .birthday, title: "", memo: "", photo: nil)
        }
        if hasAdoptionDate {
            eventRepository.create(for: rabbit, date: adoptionDate, type: .adoption, title: "", memo: "", photo: nil)
        }

        return rabbit
    }
}

/// うさぎの入力欄。Form の中に置いて使う。
struct RabbitFormFields: View {

    @Binding var draft: RabbitDraft

    var body: some View {
        Section("お名前") {
            TextField("例：モカ", text: $draft.name)
                .textInputAutocapitalization(.never)
        }

        Section("プロフィール") {
            TextField("品種（例：ネザーランドドワーフ）", text: $draft.breed)

            Picker("性別", selection: $draft.sex) {
                ForEach(Sex.allCases) { Text($0.label).tag($0) }
            }

            Toggle("誕生日を登録する", isOn: $draft.hasBirthday)
            if draft.hasBirthday {
                DatePicker("誕生日", selection: $draft.birthday, in: ...Date(), displayedComponents: .date)
            }

            Toggle("お迎え日を登録する", isOn: $draft.hasAdoptionDate)
            if draft.hasAdoptionDate {
                DatePicker("お迎え日", selection: $draft.adoptionDate, in: ...Date(), displayedComponents: .date)
            }
        }

        Section("写真") {
            PhotoField(label: "写真を選ぶ", data: $draft.photo)
        }
    }
}

/// 2羽目以降を追加するシート。
struct AddRabbitView: View {

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Rabbit.createdAt, order: .forward) private var rabbits: [Rabbit]

    @State private var draft = RabbitDraft()
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                RabbitFormFields(draft: $draft)
            }
            .navigationTitle("うさぎを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加", action: save).disabled(!draft.canSave)
                }
            }
            .alert("保存できませんでした", isPresented: $showError) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        // 画面を開いている間に上限に達している場合もあるので、保存直前にも確かめる。
        guard rabbits.count < Rabbit.maxCount else {
            errorMessage = "登録できるのは\(Rabbit.maxCount)羽までです。"
            showError = true
            return
        }

        let rabbit = draft.insert(into: context)

        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
            showError = true
            return
        }

        // 追加した子をそのまま表示する。
        settings.selectedRabbitID = rabbit.id.uuidString

        let names = rabbits.map(\.name)
        Task {
            await NotificationManager.shared.syncDailyReminder(with: settings, rabbitNames: names)
        }

        dismiss()
    }
}
