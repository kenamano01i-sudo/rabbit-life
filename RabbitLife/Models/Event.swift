import Foundation
import SwiftData

@Model
final class Event {

    @Attribute(.unique) var id: UUID
    var date: Date
    var rabbitID: UUID
    var typeRaw: String
    var title: String
    var memo: String
    @Attribute(.externalStorage) var photo: Data?
    var createdAt: Date

    var rabbit: Rabbit?

    init(
        id: UUID = UUID(),
        date: Date,
        rabbitID: UUID,
        type: EventType,
        title: String = "",
        memo: String = "",
        photo: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.rabbitID = rabbitID
        self.typeRaw = type.rawValue
        self.title = title
        self.memo = memo
        self.photo = photo
        self.createdAt = Date()
    }

    var type: EventType {
        get { EventType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    /// タイトル未入力ならイベント種別名を使う。
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? type.label : title
    }
}
