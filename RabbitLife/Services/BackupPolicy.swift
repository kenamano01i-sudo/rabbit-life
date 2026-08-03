import Foundation
import SwiftData

/// 「iCloudバックアップ」設定の実体。
/// 同期はしない。端末のバックアップに SwiftData ストアを含めるかどうかだけを切り替える。
enum BackupPolicy {

    static func apply(enabled: Bool, container: ModelContainer) {
        for configuration in container.configurations {
            apply(enabled: enabled, storeURL: configuration.url)
        }
    }

    private static func apply(enabled: Bool, storeURL: URL) {
        // SwiftData は .store のほかに -wal / -shm を作る。まとめて設定する。
        let candidates = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]

        for url in candidates {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            var mutableURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = !enabled
            try? mutableURL.setResourceValues(values)
        }
    }
}
