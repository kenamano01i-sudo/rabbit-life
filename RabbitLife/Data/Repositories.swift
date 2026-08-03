import Foundation
import SwiftData

// MARK: - Rabbit

struct RabbitRepository {

    let context: ModelContext

    func all() throws -> [Rabbit] {
        try context.fetch(
            FetchDescriptor<Rabbit>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        )
    }

    func first() throws -> Rabbit? {
        var descriptor = FetchDescriptor<Rabbit>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func create(name: String, birthday: Date?, adoptionDate: Date?, breed: String, sex: Sex, photo: Data?) -> Rabbit {
        let rabbit = Rabbit(
            name: name,
            birthday: birthday,
            adoptionDate: adoptionDate,
            breed: breed,
            sex: sex,
            photo: photo
        )
        context.insert(rabbit)
        return rabbit
    }
}

// MARK: - DailyRecord

struct DailyRecordRepository {

    let context: ModelContext

    func record(for rabbit: Rabbit, on date: Date) throws -> DailyRecord? {
        let rabbitID = rabbit.id
        let start = date.startOfDayRL
        let end = start.addingDays(1)

        var descriptor = FetchDescriptor<DailyRecord>(
            predicate: #Predicate { $0.rabbitID == rabbitID && $0.date >= start && $0.date < end }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func records(for rabbit: Rabbit, from: Date? = nil, to: Date? = nil) throws -> [DailyRecord] {
        let rabbitID = rabbit.id
        let lower = (from ?? Date.distantPast).startOfDayRL
        let upper = (to ?? Date.distantFuture).startOfDayRL.addingDays(1)

        let descriptor = FetchDescriptor<DailyRecord>(
            predicate: #Predicate { $0.rabbitID == rabbitID && $0.date >= lower && $0.date < upper },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// その日の記録を取得。なければ作って挿入する。
    func upsert(for rabbit: Rabbit, on date: Date) throws -> DailyRecord {
        if let existing = try record(for: rabbit, on: date) {
            return existing
        }
        let created = DailyRecord(date: date, rabbitID: rabbit.id)
        created.rabbit = rabbit
        context.insert(created)
        return created
    }

    func delete(_ record: DailyRecord) {
        context.delete(record)
    }
}

// MARK: - Event

struct EventRepository {

    let context: ModelContext

    func events(for rabbit: Rabbit) throws -> [Event] {
        let rabbitID = rabbit.id
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.rabbitID == rabbitID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func create(for rabbit: Rabbit, date: Date, type: EventType, title: String, memo: String, photo: Data?) -> Event {
        let event = Event(date: date, rabbitID: rabbit.id, type: type, title: title, memo: memo, photo: photo)
        event.rabbit = rabbit
        context.insert(event)
        return event
    }

    func delete(_ event: Event) {
        context.delete(event)
    }
}

// MARK: - Difference

struct DifferenceRepository {

    let context: ModelContext

    func differences(for rabbit: Rabbit, on date: Date) throws -> [Difference] {
        let rabbitID = rabbit.id
        let start = date.startOfDayRL
        let end = start.addingDays(1)

        let descriptor = FetchDescriptor<Difference>(
            predicate: #Predicate { $0.rabbitID == rabbitID && $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func differences(for rabbit: Rabbit, from: Date, to: Date) throws -> [Difference] {
        let rabbitID = rabbit.id
        let lower = from.startOfDayRL
        let upper = to.startOfDayRL.addingDays(1)

        let descriptor = FetchDescriptor<Difference>(
            predicate: #Predicate { $0.rabbitID == rabbitID && $0.date >= lower && $0.date < upper },
            sortBy: [SortDescriptor(\.date, order: .forward), SortDescriptor(\.sortOrder, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func deleteAll(for rabbit: Rabbit, on date: Date) throws {
        for difference in try differences(for: rabbit, on: date) {
            context.delete(difference)
        }
    }
}
