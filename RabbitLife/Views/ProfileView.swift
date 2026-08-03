import SwiftUI
import SwiftData

struct ProfileView: View {

    @Bindable var rabbit: Rabbit

    @Environment(\.modelContext) private var context
    @State private var isEditing = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    RabbitAvatar(photo: rabbit.photo, size: 96)
                    Text(rabbit.name).font(.title3.weight(.semibold))
                    if !rabbit.breed.isEmpty {
                        Text(rabbit.breed).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(rabbit.sex.label).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            Section {
                if let birthday = rabbit.birthday {
                    LabeledContent("誕生日", value: DateText.numeric(birthday))
                }
                if let age = rabbit.ageDescription {
                    LabeledContent("現在年齢", value: age)
                }
                if let adoptionDate = rabbit.adoptionDate {
                    LabeledContent("お迎え日", value: DateText.numeric(adoptionDate))
                }
                if let average = rabbit.averageWeight {
                    LabeledContent("平均体重", value: WeightText.kgFromKilograms(average))
                        .accessibilityHint("直近30日の平均")
                }
            }

            Section {
                LabeledContent("記録した日数", value: "\(rabbit.records.count)日")
                LabeledContent("できごと", value: "\(rabbit.events.count)件")
            }
        }
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            ProfileEditView(rabbit: rabbit)
        }
    }
}

private struct ProfileEditView: View {

    @Bindable var rabbit: Rabbit

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var hasAdoptionDate = false
    @State private var adoptionDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("お名前") {
                    TextField("名前", text: $rabbit.name)
                }

                Section("プロフィール") {
                    TextField("品種", text: $rabbit.breed)
                    Picker("性別", selection: $rabbit.sex) {
                        ForEach(Sex.allCases) { Text($0.label).tag($0) }
                    }

                    Toggle("誕生日", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker("誕生日", selection: $birthday, in: ...Date(), displayedComponents: .date)
                    }

                    Toggle("お迎え日", isOn: $hasAdoptionDate)
                    if hasAdoptionDate {
                        DatePicker("お迎え日", selection: $adoptionDate, in: ...Date(), displayedComponents: .date)
                    }
                }

                Section("写真") {
                    PhotoField(label: "写真を選ぶ", data: $rabbit.photo)
                }
            }
            .navigationTitle("プロフィールを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: save)
                }
            }
            .onAppear {
                hasBirthday = rabbit.birthday != nil
                birthday = rabbit.birthday ?? Date()
                hasAdoptionDate = rabbit.adoptionDate != nil
                adoptionDate = rabbit.adoptionDate ?? Date()
            }
        }
    }

    private func save() {
        rabbit.birthday = hasBirthday ? birthday : nil
        rabbit.adoptionDate = hasAdoptionDate ? adoptionDate : nil
        try? context.save()
        dismiss()
    }
}
