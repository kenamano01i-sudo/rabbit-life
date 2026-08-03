import SwiftUI
import SwiftData

@main
struct RabbitLifeApp: App {

    @State private var settings = AppSettings.shared

    private let container: ModelContainer

    init() {
        let schema = Schema([
            Rabbit.self,
            DailyRecord.self,
            Event.self,
            Difference.self
        ])
        // 通信なし・サーバーなし。ストアは端末内にだけ置く。
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer の作成に失敗しました: \(error)")
        }

        BackupPolicy.apply(enabled: AppSettings.shared.iCloudBackupEnabled, container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
        }
        .modelContainer(container)
    }
}
