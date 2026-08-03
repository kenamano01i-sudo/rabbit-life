import Foundation
import SwiftUI

enum SettingsKey {
    static let hasCompletedSetup = "hasCompletedSetup"
    static let notificationEnabled = "notificationEnabled"
    static let notificationHour = "notificationHour"
    static let notificationMinute = "notificationMinute"
    static let iCloudBackupEnabled = "iCloudBackupEnabled"
}

/// 設定値は端末内の UserDefaults にのみ保存する。外部送信はしない。
@Observable
final class AppSettings {

    static let shared = AppSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            SettingsKey.notificationEnabled: true,
            SettingsKey.notificationHour: 20,
            SettingsKey.notificationMinute: 0,
            SettingsKey.iCloudBackupEnabled: true
        ])
        self.hasCompletedSetup = defaults.bool(forKey: SettingsKey.hasCompletedSetup)
        self.notificationEnabled = defaults.bool(forKey: SettingsKey.notificationEnabled)
        self.notificationHour = defaults.integer(forKey: SettingsKey.notificationHour)
        self.notificationMinute = defaults.integer(forKey: SettingsKey.notificationMinute)
        self.iCloudBackupEnabled = defaults.bool(forKey: SettingsKey.iCloudBackupEnabled)
    }

    var hasCompletedSetup: Bool {
        didSet { defaults.set(hasCompletedSetup, forKey: SettingsKey.hasCompletedSetup) }
    }

    var notificationEnabled: Bool {
        didSet { defaults.set(notificationEnabled, forKey: SettingsKey.notificationEnabled) }
    }

    var notificationHour: Int {
        didSet { defaults.set(notificationHour, forKey: SettingsKey.notificationHour) }
    }

    var notificationMinute: Int {
        didSet { defaults.set(notificationMinute, forKey: SettingsKey.notificationMinute) }
    }

    var iCloudBackupEnabled: Bool {
        didSet { defaults.set(iCloudBackupEnabled, forKey: SettingsKey.iCloudBackupEnabled) }
    }

    /// 通知時刻を Date として読み書きするための橋渡し（DatePicker 用）。
    var notificationTime: Date {
        get {
            var components = DateComponents()
            components.hour = notificationHour
            components.minute = notificationMinute
            return Calendar.rabbitLife.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.rabbitLife.dateComponents([.hour, .minute], from: newValue)
            notificationHour = components.hour ?? 20
            notificationMinute = components.minute ?? 0
        }
    }
}
