import Foundation

/// エンジンが生成する Difference の素。SwiftData に依存しない値型。
struct DifferenceDraft: Identifiable, Hashable {

    var id = UUID()
    var date: Date
    var target: DifferenceTarget
    var compareType: CompareType
    var level: DifferenceLevel
    var message: String
    var previousValue: String = ""
    var currentValue: String = ""
    var icon: String
    var color: DifferenceColor
    var sortOrder: Int = 0
}

/// エンジンへ渡す DailyRecord のスナップショット。
struct RecordSnapshot: Hashable {

    var date: Date
    var appetite: Appetite
    var water: WaterIntake
    var poopAmount: PoopAmount
    var poopSize: PoopSize
    var poopShape: PoopShape
    var activity: ActivityLevel
    /// グラム。任意。
    var weightGrams: Double?

    init(
        date: Date,
        appetite: Appetite = .normal,
        water: WaterIntake = .normal,
        poopAmount: PoopAmount = .normal,
        poopSize: PoopSize = .normal,
        poopShape: PoopShape = .round,
        activity: ActivityLevel = .energetic,
        weightGrams: Double? = nil
    ) {
        self.date = date.startOfDayRL
        self.appetite = appetite
        self.water = water
        self.poopAmount = poopAmount
        self.poopSize = poopSize
        self.poopShape = poopShape
        self.activity = activity
        self.weightGrams = weightGrams
    }

    init(record: DailyRecord) {
        self.init(
            date: record.date,
            appetite: record.appetite,
            water: record.water,
            poopAmount: record.poopAmount,
            poopSize: record.poopSize,
            poopShape: record.poopShape,
            activity: record.activity,
            weightGrams: record.weightInGrams
        )
    }
}

/// エンジンへ渡す Event のスナップショット。
struct EventSnapshot: Hashable {

    var date: Date
    var type: EventType

    init(date: Date, type: EventType) {
        self.date = date.startOfDayRL
        self.type = type
    }

    init(event: Event) {
        self.init(date: event.date, type: event.type)
    }
}
