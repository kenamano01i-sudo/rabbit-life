import SwiftUI
import SwiftData

/// 初回セットアップ。ここで登録するのは1匹だけ（複数匹対応は Version 1.1）。
struct SetupView: View {

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var name = ""
    @State private var breed = ""
    @State private var sex = Sex.unknown
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var hasAdoptionDate = false
    @State private var adoptionDate = Date()
    @State private var photo: Data?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Text("🐰").font(.system(size: 44))
                        Text("はじめまして")
                            .font(.title3.weight(.semibold))
                        Text("うさぎさんのことを教えてください。\nあとから設定で変更できます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("お名前") {
                    TextField("例：モカ", text: $name)
                        .textInputAutocapitalization(.never)
                }

                Section("プロフィール") {
                    TextField("品種（例：ネザーランドドワーフ）", text: $breed)

                    Picker("性別", selection: $sex) {
                        ForEach(Sex.allCases) { Text($0.label).tag($0) }
                    }

                    Toggle("誕生日を登録する", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker("誕生日", selection: $birthday, in: ...Date(), displayedComponents: .date)
                    }

                    Toggle("お迎え日を登録する", isOn: $hasAdoptionDate)
                    if hasAdoptionDate {
                        DatePicker("お迎え日", selection: $adoptionDate, in: ...Date(), displayedComponents: .date)
                    }
                }

                Section("写真") {
                    PhotoField(label: "写真を選ぶ", data: $photo)
                }

                Section {
                    Text("記録は端末の中だけに保存されます。通信もアカウント登録もありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Rabbit Life")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("はじめる", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let repository = RabbitRepository(context: context)
        let rabbit = repository.create(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
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

        try? context.save()
        settings.hasCompletedSetup = true

        Task {
            await NotificationManager.shared.syncDailyReminder(with: settings, rabbitName: rabbit.name)
        }
    }
}
