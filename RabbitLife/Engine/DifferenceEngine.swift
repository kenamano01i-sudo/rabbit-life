import Foundation

/// Rabbit Life の心臓部。
/// DailyRecord を解析し、「昨日との違い」だけを Difference として取り出す。
///
/// 医療上の配慮（仕様書 §13）:
/// - 病名・診断名は絶対に生成しない
/// - 重い変化のときだけ「かかりつけの動物病院へご相談ください」を添える
struct DifferenceEngine {

    // MARK: - しきい値

    /// 昨日の記録がないとき、何日前までさかのぼって「前回」とみなすか。
    var maxBaselineGapDays = 7
    /// 体重の変化を「誤差」とみなす上限（g）。
    var weightNoiseGrams: Double = 5
    /// 連続日数の判定でさかのぼる上限。
    var streakWindowDays = 7

    private let calendar = Calendar.rabbitLife

    // MARK: - 入口

    /// - Parameters:
    ///   - today: 今日（対象日）の記録
    ///   - history: 同じうさぎの他の記録。対象日を含んでいてもよい
    ///   - events: 同じうさぎのイベント
    func makeDifferences(
        today: RecordSnapshot,
        history: [RecordSnapshot],
        events: [EventSnapshot] = []
    ) -> [DifferenceDraft] {

        let past = history
            .filter { $0.date < today.date }
            .sorted { $0.date > $1.date }

        var drafts: [DifferenceDraft] = []

        // 1. 昨日（なければ直近）との比較
        if let baseline = past.first, today.date.daysSince(baseline.date) <= maxBaselineGapDays {
            let isYesterday = today.date.daysSince(baseline.date) == 1
            drafts += dailyComparison(today: today, baseline: baseline, isYesterday: isYesterday)
        } else {
            drafts.append(
                DifferenceDraft(
                    date: today.date,
                    target: .event,
                    compareType: .yesterday,
                    level: .normal,
                    message: past.isEmpty
                        ? "はじめての記録です。明日から「昨日との違い」をお知らせします。"
                        : "しばらくぶりの記録です。明日から比較を再開します。",
                    icon: DifferenceTarget.event.symbolName,
                    color: .gray,
                    sortOrder: 0
                )
            )
        }

        // 2. ここ1週間の連続傾向
        drafts += streakComparison(today: today, past: past)

        // 3. 1か月前との比較
        drafts += monthComparison(today: today, past: past)

        // 4. 去年との比較
        drafts += yearComparison(today: today, past: past, events: events)

        // 5. イベントからの経過日数
        drafts += eventComparison(today: today, events: events)

        return drafts
    }

    // MARK: - 1. 昨日との比較

    private func dailyComparison(
        today: RecordSnapshot,
        baseline: RecordSnapshot,
        isYesterday: Bool
    ) -> [DifferenceDraft] {

        let ref = isYesterday ? "昨日" : "前回"
        var drafts: [DifferenceDraft] = []

        drafts.append(appetiteDraft(today: today, baseline: baseline, ref: ref))
        drafts.append(poopDraft(today: today, baseline: baseline, ref: ref))
        drafts.append(waterDraft(today: today, baseline: baseline, ref: ref))
        drafts.append(activityDraft(today: today, baseline: baseline, ref: ref))

        if let weight = weightDraft(today: today, baseline: baseline, ref: ref) {
            drafts.append(weight)
        }

        return drafts
    }

    private func appetiteDraft(today: RecordSnapshot, baseline: RecordSnapshot, ref: String) -> DifferenceDraft {

        let current = today.appetite
        let previous = baseline.appetite
        let delta = current.concern - previous.concern

        let message: String
        let level: DifferenceLevel

        if delta > 0 {
            message = delta == 1
                ? "\(ref)より少し食欲が落ちています"
                : "\(ref)より食欲が落ちています"
            level = appetiteLevel(for: current)
        } else if delta < 0 {
            message = current == .normal
                ? "\(ref)より食欲が戻っています"
                : "\(ref)より食欲が戻ってきています"
            level = current == .normal ? .normal : .notice
        } else if current == .normal {
            message = "\(ref)と同じです"
            level = .normal
        } else {
            message = "\(ref)と同じく\(current.label)です"
            level = appetiteLevel(for: current)
        }

        return DifferenceDraft(
            date: today.date,
            target: .appetite,
            compareType: .yesterday,
            level: level,
            message: message,
            previousValue: previous.label,
            currentValue: current.label,
            icon: DifferenceTarget.appetite.symbolName,
            color: level.color,
            sortOrder: DifferenceTarget.appetite.displayOrder
        )
    }

    private func appetiteLevel(for appetite: Appetite) -> DifferenceLevel {
        switch appetite {
        case .normal: return .normal
        case .slightlyLess: return .notice
        case .half: return .warning
        case .notEating: return .important
        }
    }

    private func poopDraft(today: RecordSnapshot, baseline: RecordSnapshot, ref: String) -> DifferenceDraft {

        var phrases: [String] = []

        if today.poopAmount != baseline.poopAmount {
            phrases.append(today.poopAmount.rank < baseline.poopAmount.rank ? "量が少なめです" : "量が多めです")
        }
        if today.poopSize != baseline.poopSize {
            phrases.append(today.poopSize.rank < baseline.poopSize.rank ? "少し小さめです" : "少し大きめです")
        }
        if today.poopShape != baseline.poopShape {
            phrases.append("形が\(today.poopShape.label)です")
        }

        let concernSum = today.poopAmount.concern + today.poopSize.concern + today.poopShape.concern
        let level = poopLevel(concernSum: concernSum)

        let message: String
        if phrases.isEmpty {
            message = concernSum == 0 ? "変化ありません" : "\(ref)と同じ状態が続いています"
        } else {
            message = "\(ref)より" + phrases.joined(separator: "、")
        }

        return DifferenceDraft(
            date: today.date,
            target: .poop,
            compareType: .yesterday,
            level: level,
            message: message,
            previousValue: poopSummary(baseline),
            currentValue: poopSummary(today),
            icon: DifferenceTarget.poop.symbolName,
            color: level.color,
            sortOrder: DifferenceTarget.poop.displayOrder
        )
    }

    private func poopLevel(concernSum: Int) -> DifferenceLevel {
        switch concernSum {
        case 0: return .normal
        case 1...2: return .notice
        case 3...4: return .warning
        default: return .important
        }
    }

    private func poopSummary(_ snapshot: RecordSnapshot) -> String {
        "量:\(snapshot.poopAmount.label) / サイズ:\(snapshot.poopSize.label) / 形:\(snapshot.poopShape.label)"
    }

    private func waterDraft(today: RecordSnapshot, baseline: RecordSnapshot, ref: String) -> DifferenceDraft {

        let current = today.water
        let previous = baseline.water

        let message: String
        if current == previous {
            message = current == .normal ? "変化ありません" : "\(ref)と同じく\(current.label)です"
        } else if current.rank < previous.rank {
            message = "\(ref)より飲む量が減っています"
        } else {
            message = "\(ref)より飲む量が増えています"
        }

        let level: DifferenceLevel = current.concern == 0 ? .normal : .notice

        return DifferenceDraft(
            date: today.date,
            target: .water,
            compareType: .yesterday,
            level: level,
            message: message,
            previousValue: previous.label,
            currentValue: current.label,
            icon: DifferenceTarget.water.symbolName,
            color: level.color,
            sortOrder: DifferenceTarget.water.displayOrder
        )
    }

    private func activityDraft(today: RecordSnapshot, baseline: RecordSnapshot, ref: String) -> DifferenceDraft {

        let current = today.activity
        let previous = baseline.activity

        let message: String
        if current == previous {
            message = current == .energetic ? "変化ありません" : "\(ref)と同じく\(current.label)です"
        } else if current.concern > previous.concern {
            message = current == .inactive
                ? "\(ref)よりあまり動いていません"
                : "\(ref)より少し静かです"
        } else {
            message = current == .energetic ? "\(ref)より元気そうです" : "\(ref)より動くようになっています"
        }

        let level: DifferenceLevel
        switch current {
        case .energetic: level = .normal
        case .quiet: level = .notice
        case .inactive: level = .warning
        }

        return DifferenceDraft(
            date: today.date,
            target: .activity,
            compareType: .yesterday,
            level: level,
            message: message,
            previousValue: previous.label,
            currentValue: current.label,
            icon: DifferenceTarget.activity.symbolName,
            color: level.color,
            sortOrder: DifferenceTarget.activity.displayOrder
        )
    }

    private func weightDraft(today: RecordSnapshot, baseline: RecordSnapshot, ref: String) -> DifferenceDraft? {

        guard let current = today.weightGrams, let previous = baseline.weightGrams, previous > 0 else {
            return nil
        }

        let delta = current - previous
        let absDelta = abs(delta)
        let percent = absDelta / previous * 100

        let level: DifferenceLevel
        let message: String

        if absDelta < weightNoiseGrams {
            level = .normal
            message = "変化ありません"
        } else if delta < 0 {
            if absDelta >= 60 || percent >= 3 {
                level = .important
                message = "\(Int(absDelta.rounded()))g減っています。心配な場合はかかりつけの動物病院へご相談ください。"
            } else if absDelta >= 25 {
                level = .warning
                message = "\(Int(absDelta.rounded()))g減っています"
            } else {
                level = .notice
                message = "－\(Int(absDelta.rounded()))g"
            }
        } else {
            level = absDelta >= 50 ? .notice : .normal
            message = "＋\(Int(absDelta.rounded()))g"
        }

        return DifferenceDraft(
            date: today.date,
            target: .weight,
            compareType: .yesterday,
            level: level,
            message: message,
            previousValue: WeightText.kg(previous),
            currentValue: WeightText.kg(current),
            icon: DifferenceTarget.weight.symbolName,
            color: level.color,
            sortOrder: DifferenceTarget.weight.displayOrder
        )
    }

    // MARK: - 2. ここ1週間の連続傾向

    private func streakComparison(today: RecordSnapshot, past: [RecordSnapshot]) -> [DifferenceDraft] {

        let chain = consecutiveChain(today: today, past: past)
        guard chain.count >= 2 else { return [] }

        var drafts: [DifferenceDraft] = []
        var order = 100

        // 食欲
        let appetiteStreak = chain.prefix { $0.appetite != .normal }
        if appetiteStreak.count >= 2 {
            let n = appetiteStreak.count
            let worst = appetiteStreak.map(\.appetite.concern).max() ?? 0

            if appetiteStreak.allSatisfy({ $0.appetite == .notEating }) {
                drafts.append(
                    streakDraft(
                        date: today.date,
                        target: .appetite,
                        level: .important,
                        message: "\(n)日連続で食欲がありません。心配な場合はかかりつけの動物病院へご相談ください。",
                        order: &order
                    )
                )
            } else if n >= 3 {
                drafts.append(
                    streakDraft(
                        date: today.date,
                        target: .appetite,
                        level: worst >= 2 ? .warning : .notice,
                        message: "\(n)日連続で食欲が少なめです",
                        order: &order
                    )
                )
            }
        }

        // 徐々に低下しているか（仕様書 §7）
        if isGraduallyWorsening(chain.map(\.appetite.concern)) {
            drafts.append(
                streakDraft(
                    date: today.date,
                    target: .appetite,
                    level: .warning,
                    message: "ここ数日で徐々に食欲が低下しています",
                    order: &order
                )
            )
        }

        // うんちの量
        let poopStreak = chain.prefix { $0.poopAmount == .less }
        if poopStreak.count >= 2 {
            drafts.append(
                streakDraft(
                    date: today.date,
                    target: .poop,
                    level: poopStreak.count >= 3 ? .warning : .notice,
                    message: "\(poopStreak.count)日連続でうんちが少なめです",
                    order: &order
                )
            )
        }

        // うんちのサイズ
        let sizeStreak = chain.prefix { $0.poopSize == .small }
        if sizeStreak.count >= 3 {
            drafts.append(
                streakDraft(
                    date: today.date,
                    target: .poop,
                    level: .notice,
                    message: "\(sizeStreak.count)日連続でうんちが小さめです",
                    order: &order
                )
            )
        }

        // 元気
        let activityStreak = chain.prefix { $0.activity != .energetic }
        if activityStreak.count >= 3 {
            let worst = activityStreak.map(\.activity.concern).max() ?? 0
            drafts.append(
                streakDraft(
                    date: today.date,
                    target: .activity,
                    level: worst >= 3 ? .warning : .notice,
                    message: "\(activityStreak.count)日連続で元気が少なめです",
                    order: &order
                )
            )
        }

        return drafts
    }

    private func streakDraft(
        date: Date,
        target: DifferenceTarget,
        level: DifferenceLevel,
        message: String,
        order: inout Int
    ) -> DifferenceDraft {
        defer { order += 1 }
        return DifferenceDraft(
            date: date,
            target: target,
            compareType: .lastWeek,
            level: level,
            message: message,
            icon: target.symbolName,
            color: level.color,
            sortOrder: order
        )
    }

    /// 今日から連続している日の記録を、新しい順に返す。
    private func consecutiveChain(today: RecordSnapshot, past: [RecordSnapshot]) -> [RecordSnapshot] {
        var chain = [today]
        var expected = today.date.addingDays(-1)

        for snapshot in past {
            guard chain.count < streakWindowDays else { break }
            guard snapshot.date == expected else { break }
            chain.append(snapshot)
            expected = expected.addingDays(-1)
        }
        return chain
    }

    /// concerns は新しい順。3日以上かけて単調に悪化しているか。
    private func isGraduallyWorsening(_ concerns: [Int]) -> Bool {
        guard concerns.count >= 3 else { return false }
        let window = Array(concerns.prefix(4))
        guard let first = window.first, let last = window.last, first > last else { return false }
        for index in 0..<(window.count - 1) where window[index] < window[index + 1] {
            return false
        }
        return true
    }

    // MARK: - 3. 1か月前との比較

    private func monthComparison(today: RecordSnapshot, past: [RecordSnapshot]) -> [DifferenceDraft] {

        guard let current = today.weightGrams else { return [] }
        guard let reference = nearestRecord(to: today.date.addingDays(-30), in: past, tolerance: 5, requiringWeight: true),
              let previous = reference.weightGrams, previous > 0 else { return [] }

        let delta = current - previous
        let absDelta = abs(delta)
        guard absDelta >= 30 else { return [] }

        let level: DifferenceLevel
        if delta < 0 {
            level = absDelta >= 80 ? .warning : .notice
        } else {
            level = .normal
        }

        let message = delta > 0
            ? "1か月前より\(Int(absDelta.rounded()))g増えています"
            : "1か月前より\(Int(absDelta.rounded()))g減っています"

        return [
            DifferenceDraft(
                date: today.date,
                target: .weight,
                compareType: .lastMonth,
                level: level,
                message: message,
                previousValue: WeightText.kg(previous),
                currentValue: WeightText.kg(current),
                icon: DifferenceTarget.weight.symbolName,
                color: level.color,
                sortOrder: 200
            )
        ]
    }

    // MARK: - 4. 去年との比較

    private func yearComparison(
        today: RecordSnapshot,
        past: [RecordSnapshot],
        events: [EventSnapshot]
    ) -> [DifferenceDraft] {

        var drafts: [DifferenceDraft] = []
        var order = 300

        guard let lastYearDate = calendar.date(byAdding: .year, value: -1, to: today.date) else { return [] }

        if let reference = nearestRecord(to: lastYearDate, in: past, tolerance: 3, requiringWeight: false) {

            if today.appetite.concern > 0 && reference.appetite.concern > 0 {
                drafts.append(
                    DifferenceDraft(
                        date: today.date,
                        target: .appetite,
                        compareType: .lastYear,
                        level: .normal,
                        message: "去年の今ごろも食欲が少なめでした",
                        previousValue: reference.appetite.label,
                        currentValue: today.appetite.label,
                        icon: DifferenceTarget.appetite.symbolName,
                        color: .gray,
                        sortOrder: order
                    )
                )
                order += 1
            }

            if let current = today.weightGrams, let previous = reference.weightGrams, previous > 0 {
                let delta = current - previous
                if abs(delta) >= 50 {
                    let message = delta > 0
                        ? "去年の今ごろより\(Int(delta.rounded()))g増えています"
                        : "去年の今ごろより\(Int(abs(delta).rounded()))g減っています"
                    drafts.append(
                        DifferenceDraft(
                            date: today.date,
                            target: .weight,
                            compareType: .lastYear,
                            level: .normal,
                            message: message,
                            previousValue: WeightText.kg(previous),
                            currentValue: WeightText.kg(current),
                            icon: DifferenceTarget.weight.symbolName,
                            color: .gray,
                            sortOrder: order
                        )
                    )
                    order += 1
                }
            }
        }

        // 去年の同時期に換毛が始まっていたか
        let moltLastYear = events.first { event in
            event.type == .moltStart && abs(event.date.daysSince(lastYearDate)) <= 14
        }
        if moltLastYear != nil {
            drafts.append(
                DifferenceDraft(
                    date: today.date,
                    target: .event,
                    compareType: .lastYear,
                    level: .normal,
                    message: "去年もこの時期に換毛が始まりました",
                    icon: EventType.moltStart.symbolName,
                    color: .gray,
                    sortOrder: order
                )
            )
        }

        return drafts
    }

    // MARK: - 5. イベントからの経過日数

    private func eventComparison(today: RecordSnapshot, events: [EventSnapshot]) -> [DifferenceDraft] {

        var drafts: [DifferenceDraft] = []
        var order = 400
        let pastEvents = events.filter { $0.date <= today.date }

        // 換毛中かどうか
        if let moltStart = pastEvents.filter({ $0.type == .moltStart }).max(by: { $0.date < $1.date }) {
            let endedAfter = pastEvents.contains { $0.type == .moltEnd && $0.date >= moltStart.date }
            let days = today.date.daysSince(moltStart.date)
            if !endedAfter && days >= 1 && days <= 90 {
                drafts.append(
                    DifferenceDraft(
                        date: today.date,
                        target: .event,
                        compareType: .lastMonth,
                        level: .normal,
                        message: "換毛開始から\(days)日",
                        icon: EventType.moltStart.symbolName,
                        color: .gray,
                        sortOrder: order
                    )
                )
                order += 1
            }
        }

        // 爪切りからの経過
        if let nail = pastEvents.filter({ $0.type == .nailClip }).max(by: { $0.date < $1.date }) {
            let days = today.date.daysSince(nail.date)
            if days >= 28 {
                drafts.append(
                    DifferenceDraft(
                        date: today.date,
                        target: .event,
                        compareType: .lastMonth,
                        level: days >= 56 ? .notice : .normal,
                        message: "前回の爪切りから\(days)日",
                        icon: EventType.nailClip.symbolName,
                        color: days >= 56 ? DifferenceLevel.notice.color : .gray,
                        sortOrder: order
                    )
                )
            }
        }

        return drafts
    }

    // MARK: - 共通ヘルパー

    private func nearestRecord(
        to target: Date,
        in records: [RecordSnapshot],
        tolerance: Int,
        requiringWeight: Bool
    ) -> RecordSnapshot? {
        records
            .filter { !requiringWeight || $0.weightGrams != nil }
            .filter { abs($0.date.daysSince(target)) <= tolerance }
            .min { abs($0.date.daysSince(target)) < abs($1.date.daysSince(target)) }
    }
}

// MARK: - まとめ文言

extension DifferenceEngine {

    /// ホーム／保存完了画面のヘッドライン。
    static func summary(for differences: [Difference], rabbitName: String) -> String {
        summary(levels: differences.map(\.level), rabbitName: rabbitName)
    }

    static func summary(for drafts: [DifferenceDraft], rabbitName: String) -> String {
        summary(levels: drafts.map(\.level), rabbitName: rabbitName)
    }

    private static func summary(levels: [DifferenceLevel], rabbitName: String) -> String {
        guard let worst = levels.max() else {
            return "今日の記録はまだありません。"
        }
        switch worst {
        case .normal:
            return "今日は大きな変化はありません。"
        case .notice:
            return "少しだけいつもと違うところがあります。"
        case .warning:
            return "いつもと違うところがあります。様子を見てあげてください。"
        case .important:
            return "気になる変化があります。心配な場合はかかりつけの動物病院へご相談ください。"
        }
    }

    /// 保存完了画面のひとこと。
    static func encouragement(for drafts: [DifferenceDraft]) -> (emoji: String, text: String) {
        switch drafts.map(\.level).max() ?? .normal {
        case .normal:
            return ("😊", "今日も元気そうですね")
        case .notice:
            return ("🙂", "少し気にかけてあげてください")
        case .warning:
            return ("😐", "今日は様子をよく見てあげてください")
        case .important:
            return ("😟", "無理をせず、かかりつけの動物病院にご相談ください")
        }
    }
}

// MARK: - 体重表示

enum WeightText {

    /// グラム値を "1.82kg" 形式へ。
    static func kg(_ grams: Double) -> String {
        String(format: "%.2fkg", grams / 1000)
    }

    static func kgFromKilograms(_ kilograms: Double) -> String {
        String(format: "%.2fkg", kilograms)
    }
}
