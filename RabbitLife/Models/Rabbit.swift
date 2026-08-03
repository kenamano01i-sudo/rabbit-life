import Foundation
import SwiftData

@Model
final class Rabbit {

    @Attribute(.unique) var id: UUID
    var name: String
    var birthday: Date?
    var adoptionDate: Date?
    var breed: String
    var sexRaw: String
    @Attribute(.externalStorage) var photo: Data?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DailyRecord.rabbit)
    var records: [DailyRecord]

    @Relationship(deleteRule: .cascade, inverse: \Event.rabbit)
    var events: [Event]

    @Relationship(deleteRule: .cascade, inverse: \Difference.rabbit)
    var differences: [Difference]

    init(
        id: UUID = UUID(),
        name: String,
        birthday: Date? = nil,
        adoptionDate: Date? = nil,
        breed: String = "",
        sex: Sex = .unknown,
        photo: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.birthday = birthday
        self.adoptionDate = adoptionDate
        self.breed = breed
        self.sexRaw = sex.rawValue
        self.photo = photo
        self.createdAt = createdAt
        self.records = []
        self.events = []
        self.differences = []
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .unknown }
        set { sexRaw = newValue.rawValue }
    }

    /// 「3歳」のような表示用の年齢。誕生日未設定なら nil。
    var ageDescription: String? {
        guard let birthday else { return nil }
        let calendar = Calendar.rabbitLife
        let parts = calendar.dateComponents([.year, .month], from: birthday, to: Date())
        guard let years = parts.year, let months = parts.month else { return nil }
        if years <= 0 {
            return "\(max(months, 0))か月"
        }
        return "\(years)歳"
    }

    /// 直近30日の体重の平均（kg）。記録がなければ nil。
    var averageWeight: Double? {
        let calendar = Calendar.rabbitLife
        guard let from = calendar.date(byAdding: .day, value: -30, to: Date()) else { return nil }
        let weights = records
            .filter { $0.date >= from }
            .compactMap { $0.weight }
        guard !weights.isEmpty else { return nil }
        return weights.reduce(0, +) / Double(weights.count)
    }
}
