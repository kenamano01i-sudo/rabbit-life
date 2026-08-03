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

            Section("かかりつけ医") {
                if rabbit.hasClinicInfo {
                    ClinicInfo(rabbit: rabbit)
                } else {
                    Text("未登録です。「編集」から登録できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

/// 住所はマップアプリ、電話番号は電話アプリに渡す。
/// 通院が必要な場面ではすぐ動けることが大事なので、値をタップするだけで開くようにしている。
private struct ClinicInfo: View {

    let rabbit: Rabbit

    @Environment(\.openURL) private var openURL

    var body: some View {
        if !rabbit.clinicName.isEmpty {
            LabeledContent("病院名", value: rabbit.clinicName)
        }

        if let url = ContactLink.maps(address: rabbit.clinicAddress) {
            ActionRow(
                title: "住所",
                systemImage: "mappin.and.ellipse",
                value: rabbit.clinicAddress,
                hint: "マップアプリで開きます"
            ) {
                openURL(url)
            }
        } else if !rabbit.clinicAddress.isEmpty {
            LabeledContent("住所", value: rabbit.clinicAddress)
        }

        if let url = ContactLink.tel(phone: rabbit.clinicPhone) {
            ActionRow(
                title: "電話番号",
                systemImage: "phone",
                value: rabbit.clinicPhone,
                hint: "電話をかけます"
            ) {
                openURL(url)
            }
        } else if !rabbit.clinicPhone.isEmpty {
            LabeledContent("電話番号", value: rabbit.clinicPhone)
        }

        if !rabbit.clinicNote.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("メモ")
                    .font(.subheadline)
                Text(rabbit.clinicNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// タップできることが色でしか分からないと気づけないので、アイコンも添える。
private struct ActionRow: View {

    let title: String
    let systemImage: String
    let value: String
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LabeledContent {
                Text(value)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.accentColor)
            } label: {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(Color.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
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

                Section {
                    TextField("病院名", text: $rabbit.clinicName)

                    TextField("住所", text: $rabbit.clinicAddress, axis: .vertical)
                        .lineLimit(1...3)
                        .textContentType(.fullStreetAddress)

                    TextField("電話番号", text: $rabbit.clinicPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)

                    TextField("メモ（任意）", text: $rabbit.clinicNote, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("かかりつけ医")
                } footer: {
                    Text("住所をタップするとマップアプリ、電話番号をタップすると電話が開きます。")
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
