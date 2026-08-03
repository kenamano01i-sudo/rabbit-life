import Foundation
import SwiftData

/// DailyRecord 保存 → DifferenceEngine 起動 → Difference 生成・保存
/// （データモデル設計 §9 / §20）
@MainActor
struct DifferenceService {

    let context: ModelContext
    var engine = DifferenceEngine()

    init(context: ModelContext, engine: DifferenceEngine = DifferenceEngine()) {
        self.context = context
        self.engine = engine
    }

    /// 指定日の Difference を作り直して保存し、生成された内容を返す。
    @discardableResult
    func regenerate(for rabbit: Rabbit, on date: Date) throws -> [DifferenceDraft] {

        let day = date.startOfDayRL
        let recordRepo = DailyRecordRepository(context: context)
        let eventRepo = EventRepository(context: context)
        let differenceRepo = DifferenceRepository(context: context)

        try differenceRepo.deleteAll(for: rabbit, on: day)

        guard let todayRecord = try recordRepo.record(for: rabbit, on: day) else {
            try context.save()
            return []
        }

        // 去年比較のため1年ちょっと前まで読む。
        let history = try recordRepo.records(for: rabbit, from: day.addingDays(-400), to: day)
            .map(RecordSnapshot.init(record:))
        let events = try eventRepo.events(for: rabbit)
            .map(EventSnapshot.init(event:))

        let drafts = engine.makeDifferences(
            today: RecordSnapshot(record: todayRecord),
            history: history,
            events: events
        )

        for draft in drafts {
            let difference = Difference(draft: draft, rabbitID: rabbit.id)
            difference.rabbit = rabbit
            context.insert(difference)
        }

        try context.save()
        return drafts
    }

    /// 記録を書き換えると翌日以降の比較結果も変わるため、後続日も作り直す。
    func regenerateFollowingDays(for rabbit: Rabbit, from date: Date, limit: Int = 7) throws {
        var day = date.startOfDayRL.addingDays(1)
        let today = Date().startOfDayRL
        var remaining = limit

        while day <= today && remaining > 0 {
            try regenerate(for: rabbit, on: day)
            day = day.addingDays(1)
            remaining -= 1
        }
    }
}
