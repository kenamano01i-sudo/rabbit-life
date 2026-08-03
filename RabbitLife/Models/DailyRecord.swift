import Foundation
import SwiftData

/// 1日ぶんの入力データ。事実だけを持ち、解釈は Difference が持つ。
@Model
final class DailyRecord {

    @Attribute(.unique) var id: UUID
    /// その日の 00:00 に正規化して保存する。
    var date: Date
    /// #Predicate でうさぎを絞り込むための非正規化フィールド。
    var rabbitID: UUID

    var appetiteRaw: String
    var waterRaw: String
    var poopAmountRaw: String
    var poopSizeRaw: String
    var poopShapeRaw: String
    var activityRaw: String

    /// kg。任意入力。
    var weight: Double?
    var memo: String
    @Attribute(.externalStorage) var photo: Data?

    var createdAt: Date
    var updatedAt: Date

    var rabbit: Rabbit?

    init(
        id: UUID = UUID(),
        date: Date,
        rabbitID: UUID,
        appetite: Appetite = .normal,
        water: WaterIntake = .normal,
        poopAmount: PoopAmount = .normal,
        poopSize: PoopSize = .normal,
        poopShape: PoopShape = .round,
        activity: ActivityLevel = .energetic,
        weight: Double? = nil,
        memo: String = "",
        photo: Data? = nil
    ) {
        self.id = id
        self.date = Calendar.rabbitLife.startOfDay(for: date)
        self.rabbitID = rabbitID
        self.appetiteRaw = appetite.rawValue
        self.waterRaw = water.rawValue
        self.poopAmountRaw = poopAmount.rawValue
        self.poopSizeRaw = poopSize.rawValue
        self.poopShapeRaw = poopShape.rawValue
        self.activityRaw = activity.rawValue
        self.weight = weight
        self.memo = memo
        self.photo = photo
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var appetite: Appetite {
        get { Appetite(rawValue: appetiteRaw) ?? .normal }
        set { appetiteRaw = newValue.rawValue }
    }

    var water: WaterIntake {
        get { WaterIntake(rawValue: waterRaw) ?? .normal }
        set { waterRaw = newValue.rawValue }
    }

    var poopAmount: PoopAmount {
        get { PoopAmount(rawValue: poopAmountRaw) ?? .normal }
        set { poopAmountRaw = newValue.rawValue }
    }

    var poopSize: PoopSize {
        get { PoopSize(rawValue: poopSizeRaw) ?? .normal }
        set { poopSizeRaw = newValue.rawValue }
    }

    var poopShape: PoopShape {
        get { PoopShape(rawValue: poopShapeRaw) ?? .round }
        set { poopShapeRaw = newValue.rawValue }
    }

    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .energetic }
        set { activityRaw = newValue.rawValue }
    }

    /// 体重をグラム単位で返す。
    var weightInGrams: Double? {
        guard let weight else { return nil }
        return weight * 1000
    }
}
