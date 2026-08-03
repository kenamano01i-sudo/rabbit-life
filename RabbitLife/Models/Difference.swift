import Foundation
import SwiftData

/// Rabbit Life の中心モデル。
/// DailyRecord が「事実」なら、Difference は「気付き」である。
/// ホーム画面・カレンダー・通知はすべてこれだけを読む。
@Model
final class Difference {

    @Attribute(.unique) var id: UUID
    var date: Date
    var rabbitID: UUID

    var targetRaw: String
    var compareTypeRaw: String
    var levelRaw: Int
    var message: String
    var previousValue: String
    var currentValue: String
    var icon: String
    var colorRaw: String
    var sortOrder: Int
    var createdAt: Date

    var rabbit: Rabbit?

    init(
        id: UUID = UUID(),
        date: Date,
        rabbitID: UUID,
        target: DifferenceTarget,
        compareType: CompareType,
        level: DifferenceLevel,
        message: String,
        previousValue: String = "",
        currentValue: String = "",
        icon: String,
        color: DifferenceColor,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.date = Calendar.rabbitLife.startOfDay(for: date)
        self.rabbitID = rabbitID
        self.targetRaw = target.rawValue
        self.compareTypeRaw = compareType.rawValue
        self.levelRaw = level.rawValue
        self.message = message
        self.previousValue = previousValue
        self.currentValue = currentValue
        self.icon = icon
        self.colorRaw = color.rawValue
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    convenience init(draft: DifferenceDraft, rabbitID: UUID) {
        self.init(
            date: draft.date,
            rabbitID: rabbitID,
            target: draft.target,
            compareType: draft.compareType,
            level: draft.level,
            message: draft.message,
            previousValue: draft.previousValue,
            currentValue: draft.currentValue,
            icon: draft.icon,
            color: draft.color,
            sortOrder: draft.sortOrder
        )
    }

    var target: DifferenceTarget {
        get { DifferenceTarget(rawValue: targetRaw) ?? .event }
        set { targetRaw = newValue.rawValue }
    }

    var compareType: CompareType {
        get { CompareType(rawValue: compareTypeRaw) ?? .yesterday }
        set { compareTypeRaw = newValue.rawValue }
    }

    var level: DifferenceLevel {
        get { DifferenceLevel(rawValue: levelRaw) ?? .normal }
        set { levelRaw = newValue.rawValue }
    }

    var color: DifferenceColor {
        get { DifferenceColor(rawValue: colorRaw) ?? .gray }
        set { colorRaw = newValue.rawValue }
    }
}
