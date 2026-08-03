import Foundation
import UserNotifications

/// ローカル通知のみ。サーバーもプッシュ証明書も使わない。
@MainActor
final class NotificationManager {

    static let shared = NotificationManager()

    private let dailyReminderID = "rabbitlife.daily.reminder"
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    /// 設定に合わせて毎日のリマインダーを張り直す。
    func syncDailyReminder(with settings: AppSettings, rabbitName: String?) async {
        cancelDailyReminder()
        guard settings.notificationEnabled else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = rabbitName.map { "\($0)の今日の様子" } ?? "Rabbit Life"
        content.body = "今日の様子を記録しませんか？"
        content.sound = .default

        var components = DateComponents()
        components.hour = settings.notificationHour
        components.minute = settings.notificationMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)

        try? await center.add(request)
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }

    /// warning 以上の Difference が出たときだけ、その場で1回だけ知らせる
    /// （データモデル設計 §14）。診断はせず、気付きだけを伝える。
    func notifyIfNeeded(drafts: [DifferenceDraft], settings: AppSettings) async {
        guard settings.notificationEnabled else { return }
        guard let worst = drafts.filter({ $0.level >= .warning }).max(by: { $0.level < $1.level }) else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = "いつもと違うところがあります"
        content.body = worst.message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "rabbitlife.difference.\(worst.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        try? await center.add(request)
    }
}
