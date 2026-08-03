import SwiftUI
import SwiftData

struct SettingsView: View {

    let rabbit: Rabbit

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query private var records: [DailyRecord]
    @State private var exportURL: URL?
    @State private var notificationDenied = false

    init(rabbit: Rabbit) {
        self.rabbit = rabbit
        let rabbitID = rabbit.id
        _records = Query(
            filter: #Predicate<DailyRecord> { $0.rabbitID == rabbitID },
            sort: [SortDescriptor(\DailyRecord.date, order: .forward)]
        )
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfileView(rabbit: rabbit)
                    } label: {
                        HStack(spacing: 12) {
                            RabbitAvatar(photo: rabbit.photo, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rabbit.name).font(.body)
                                Text("プロフィール").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("通知") {
                    Toggle("毎日のお知らせ", isOn: $settings.notificationEnabled)
                    if settings.notificationEnabled {
                        DatePicker(
                            "通知時間",
                            selection: $settings.notificationTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    if notificationDenied {
                        Text("iOSの設定で通知が許可されていません。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("iCloudバックアップに含める", isOn: $settings.iCloudBackupEnabled)
                } footer: {
                    Text("記録は端末内にのみ保存されます。ONにすると端末のiCloudバックアップに記録が含まれます。データがサーバーへ送信されることはありません。")
                }

                Section("書き出し") {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("CSVで書き出す", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label("CSVで書き出す", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("このアプリについて") {
                    NavigationLink("利用規約") { LegalTextView(document: .terms) }
                    NavigationLink("プライバシーポリシー") { LegalTextView(document: .privacy) }
                    LabeledContent("バージョン", value: Bundle.main.appVersionText)
                }

                Section {
                    Text("Rabbit Life は診断を行いません。気になる変化があるときは、かかりつけの動物病院へご相談ください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            exportURL = ExportService.writeCSV(rabbit: rabbit, records: records)
            if settings.notificationEnabled {
                notificationDenied = !(await NotificationManager.shared.requestAuthorizationIfNeeded())
            } else {
                notificationDenied = false
            }
        }
        .onChange(of: settings.notificationEnabled) { _, _ in syncNotification() }
        .onChange(of: settings.notificationHour) { _, _ in syncNotification() }
        .onChange(of: settings.notificationMinute) { _, _ in syncNotification() }
        .onChange(of: settings.iCloudBackupEnabled) { _, enabled in
            BackupPolicy.apply(enabled: enabled, container: context.container)
        }
    }

    private func syncNotification() {
        Task {
            await NotificationManager.shared.syncDailyReminder(with: settings, rabbitName: rabbit.name)
        }
    }
}

extension Bundle {
    var appVersionText: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
