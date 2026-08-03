import Foundation

extension Calendar {
    /// アプリ全体で使うカレンダー。週の始まりは月曜（画面設計 §7）。
    static let rabbitLife: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }()
}

extension Date {
    var startOfDayRL: Date {
        Calendar.rabbitLife.startOfDay(for: self)
    }

    func addingDays(_ days: Int) -> Date {
        Calendar.rabbitLife.date(byAdding: .day, value: days, to: self) ?? self
    }

    func isSameDayRL(as other: Date) -> Bool {
        Calendar.rabbitLife.isDate(self, inSameDayAs: other)
    }

    /// 日単位の差。self が other より後なら正。
    func daysSince(_ other: Date) -> Int {
        let from = other.startOfDayRL
        let to = startOfDayRL
        return Calendar.rabbitLife.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

enum DateText {

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar.rabbitLife
        f.dateFormat = format
        return f
    }

    /// 8月3日（月）
    static func longDay(_ date: Date) -> String {
        formatter("M月d日（E）").string(from: date)
    }

    /// 8/3
    static func shortDay(_ date: Date) -> String {
        formatter("M/d").string(from: date)
    }

    /// 2026年8月
    static func yearMonth(_ date: Date) -> String {
        formatter("yyyy年M月").string(from: date)
    }

    /// 2026
    static func year(_ date: Date) -> String {
        formatter("yyyy").string(from: date)
    }

    /// 2023/5/14
    static func numeric(_ date: Date) -> String {
        formatter("yyyy/M/d").string(from: date)
    }
}
