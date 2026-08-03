import SwiftUI
import SwiftData

struct SettingsView: View {

    let rabbit: Rabbit

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query private var records: [DailyRecord]
    @Query(sort: \Rabbit.createdAt, order: .forward) private var rabbits: [Rabbit]

    @State private var exportURL: URL?
    @State private var notificationDenied = false

    @State private var showAddRabbit = false
    @State private var rabbitToDelete: Rabbit?
    @State private var errorMessage: String?
    @State private var showError = false

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
                    ForEach(rabbits) { candidate in
                        NavigationLink {
                            ProfileView(rabbit: candidate)
                        } label: {
                            HStack(spacing: 12) {
                                RabbitAvatar(photo: candidate.photo, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name).font(.body)
                                    Text(candidate.id == rabbit.id ? "表示中・プロフィール" : "プロフィール")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            // 最後の1羽まで消せると記録が全部なくなってしまうので残す。
                            if rabbits.count > 1 {
                                Button("削除", role: .destructive) { rabbitToDelete = candidate }
                            }
                        }
                    }

                    Button {
                        showAddRabbit = true
                    } label: {
                        Label("うさぎを追加", systemImage: "plus")
                    }
                    .disabled(rabbits.count >= Rabbit.maxCount)
                } header: {
                    Text("うさぎ")
                } footer: {
                    if rabbits.count >= Rabbit.maxCount {
                        Text("登録できるのは\(Rabbit.maxCount)羽までです。")
                    } else if rabbits.count > 1 {
                        Text("最大\(Rabbit.maxCount)羽まで登録できます。表示するうさぎはホームで切り替えられます。")
                    } else {
                        Text("最大\(Rabbit.maxCount)羽まで登録できます。")
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
        .sheet(isPresented: $showAddRabbit) {
            AddRabbitView()
        }
        .confirmationDialog(
            rabbitToDelete.map { "\($0.name)を削除しますか？" } ?? "",
            isPresented: Binding(get: { rabbitToDelete != nil }, set: { if !$0 { rabbitToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let target = rabbitToDelete { delete(target) }
                rabbitToDelete = nil
            }
            Button("キャンセル", role: .cancel) { rabbitToDelete = nil }
        } message: {
            Text("記録・できごと・写真もすべて消えます。この操作は取り消せません。")
        }
        .alert("削除できませんでした", isPresented: $showError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func delete(_ target: Rabbit) {
        let wasSelected = target.id == rabbit.id
        context.delete(target)

        do {
            try context.save()
        } catch {
            // delete はメモリ上に適用済みなので、戻さないと画面からは消えたまま
            // 次回起動時に復活する。
            context.rollback()
            errorMessage = error.localizedDescription
            showError = true
            return
        }

        // 表示中の子を消したときは、残っている先頭に移す。
        if wasSelected {
            settings.selectedRabbitID = rabbits.first(where: { $0.id != target.id })?.id.uuidString
        }

        syncNotification()
    }

    private func syncNotification() {
        let names = rabbits.map(\.name)
        Task {
            await NotificationManager.shared.syncDailyReminder(with: settings, rabbitNames: names)
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
