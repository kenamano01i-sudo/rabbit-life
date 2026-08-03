import XCTest
@testable import RabbitLife

/// DifferenceEngine は SwiftData に依存しない純粋な関数なので、
/// スナップショットを組み立てるだけでテストできる。
final class DifferenceEngineTests: XCTestCase {

    private let engine = DifferenceEngine()

    private var today: Date {
        Calendar.rabbitLife.date(from: DateComponents(year: 2026, month: 8, day: 3))!
    }

    private func day(_ offset: Int) -> Date {
        today.addingDays(offset)
    }

    private func draft(
        _ drafts: [DifferenceDraft],
        target: DifferenceTarget,
        compare: CompareType
    ) -> DifferenceDraft? {
        drafts.first { $0.target == target && $0.compareType == compare }
    }

    // MARK: - 昨日との比較

    func testAppetiteDropFromYesterdayIsNotice() {
        let yesterday = RecordSnapshot(date: day(-1), appetite: .normal)
        let now = RecordSnapshot(date: day(0), appetite: .slightlyLess)

        let drafts = engine.makeDifferences(today: now, history: [yesterday])
        let appetite = draft(drafts, target: .appetite, compare: .yesterday)

        XCTAssertEqual(appetite?.level, .notice)
        XCTAssertEqual(appetite?.message, "昨日より少し食欲が落ちています")
        XCTAssertEqual(appetite?.previousValue, "普通")
        XCTAssertEqual(appetite?.currentValue, "少し少ない")
    }

    func testNoChangeProducesNormalLevelsOnly() {
        let yesterday = RecordSnapshot(date: day(-1))
        let now = RecordSnapshot(date: day(0))

        let drafts = engine.makeDifferences(today: now, history: [yesterday])

        XCTAssertEqual(drafts.map(\.level).max(), .normal)
        XCTAssertEqual(
            DifferenceEngine.summary(for: drafts, rabbitName: "モカ"),
            "今日は大きな変化はありません。"
        )
    }

    func testPoopSizeChangeIsReported() {
        let yesterday = RecordSnapshot(date: day(-1), poopSize: .normal)
        let now = RecordSnapshot(date: day(0), poopSize: .small)

        let drafts = engine.makeDifferences(today: now, history: [yesterday])
        let poop = draft(drafts, target: .poop, compare: .yesterday)

        XCTAssertEqual(poop?.message, "昨日より少し小さめです")
        XCTAssertEqual(poop?.level, .notice)
    }

    // MARK: - 体重

    func testWeightDropOf30gIsWarning() {
        let yesterday = RecordSnapshot(date: day(-1), weightGrams: 1820)
        let now = RecordSnapshot(date: day(0), weightGrams: 1790)

        let drafts = engine.makeDifferences(today: now, history: [yesterday])
        let weight = draft(drafts, target: .weight, compare: .yesterday)

        XCTAssertEqual(weight?.level, .warning)
        XCTAssertEqual(weight?.message, "30g減っています")
    }

    func testSmallWeightGainIsShownButNormal() {
        let yesterday = RecordSnapshot(date: day(-1), weightGrams: 1810)
        let now = RecordSnapshot(date: day(0), weightGrams: 1820)

        let drafts = engine.makeDifferences(today: now, history: [yesterday])
        let weight = draft(drafts, target: .weight, compare: .yesterday)

        XCTAssertEqual(weight?.level, .normal)
        XCTAssertEqual(weight?.message, "＋10g")
    }

    func testWeightIsSkippedWhenNotRecorded() {
        let yesterday = RecordSnapshot(date: day(-1), weightGrams: 1820)
        let now = RecordSnapshot(date: day(0), weightGrams: nil)

        let drafts = engine.makeDifferences(today: now, history: [yesterday])

        XCTAssertNil(draft(drafts, target: .weight, compare: .yesterday))
    }

    // MARK: - 連続傾向

    func testThreeDayAppetiteStreak() {
        let history = [
            RecordSnapshot(date: day(-1), appetite: .slightlyLess),
            RecordSnapshot(date: day(-2), appetite: .slightlyLess)
        ]
        let now = RecordSnapshot(date: day(0), appetite: .slightlyLess)

        let drafts = engine.makeDifferences(today: now, history: history)
        let streak = draft(drafts, target: .appetite, compare: .lastWeek)

        XCTAssertEqual(streak?.message, "3日連続で食欲が少なめです")
        XCTAssertEqual(streak?.level, .notice)
    }

    func testTwoDaysWithoutEatingIsImportantAndSuggestsVet() {
        let history = [RecordSnapshot(date: day(-1), appetite: .notEating)]
        let now = RecordSnapshot(date: day(0), appetite: .notEating)

        let drafts = engine.makeDifferences(today: now, history: history)
        let streak = draft(drafts, target: .appetite, compare: .lastWeek)

        XCTAssertEqual(streak?.level, .important)
        XCTAssertEqual(streak?.message, "2日連続で食欲がありません。心配な場合はかかりつけの動物病院へご相談ください。")
    }

    func testGradualDeclineIsDetected() {
        let history = [
            RecordSnapshot(date: day(-1), appetite: .slightlyLess),
            RecordSnapshot(date: day(-2), appetite: .normal),
            RecordSnapshot(date: day(-3), appetite: .normal)
        ]
        let now = RecordSnapshot(date: day(0), appetite: .half)

        let drafts = engine.makeDifferences(today: now, history: history)
        let messages = drafts.filter { $0.compareType == .lastWeek }.map(\.message)

        XCTAssertTrue(messages.contains("ここ数日で徐々に食欲が低下しています"))
    }

    func testStreakIsBrokenByAMissingDay() {
        // 2日前の記録がないので「連続」にはならない。
        let history = [
            RecordSnapshot(date: day(-1), appetite: .slightlyLess),
            RecordSnapshot(date: day(-3), appetite: .slightlyLess)
        ]
        let now = RecordSnapshot(date: day(0), appetite: .slightlyLess)

        let drafts = engine.makeDifferences(today: now, history: history)

        XCTAssertNil(draft(drafts, target: .appetite, compare: .lastWeek))
    }

    // MARK: - 長期比較

    func testLastYearMoltIsMentioned() {
        let lastYear = Calendar.rabbitLife.date(byAdding: .year, value: -1, to: today)!
        let events = [EventSnapshot(date: lastYear.addingDays(-4), type: .moltStart)]

        let drafts = engine.makeDifferences(
            today: RecordSnapshot(date: day(0)),
            history: [RecordSnapshot(date: day(-1))],
            events: events
        )

        XCTAssertTrue(drafts.contains { $0.message == "去年もこの時期に換毛が始まりました" })
    }

    func testDaysSinceNailClipIsReported() {
        let events = [EventSnapshot(date: day(-28), type: .nailClip)]

        let drafts = engine.makeDifferences(
            today: RecordSnapshot(date: day(0)),
            history: [RecordSnapshot(date: day(-1))],
            events: events
        )

        XCTAssertTrue(drafts.contains { $0.message == "前回の爪切りから28日" })
    }

    // MARK: - 初回

    func testFirstRecordExplainsItself() {
        let drafts = engine.makeDifferences(today: RecordSnapshot(date: day(0)), history: [])

        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts.first?.message, "はじめての記録です。明日から「昨日との違い」をお知らせします。")
    }

    // MARK: - 医療上の配慮（仕様書 §13）

    func testNoDiagnosticVocabularyIsEverGenerated() {
        let banned = ["病気", "うっ滞", "診断", "疾患", "治療", "症"]

        let cases: [(RecordSnapshot, [RecordSnapshot])] = [
            (RecordSnapshot(date: day(0), appetite: .notEating, poopAmount: .less, poopSize: .small, activity: .inactive, weightGrams: 1700),
             [RecordSnapshot(date: day(-1), appetite: .notEating, weightGrams: 1820)]),
            (RecordSnapshot(date: day(0)), [RecordSnapshot(date: day(-1))])
        ]

        for (now, history) in cases {
            for message in engine.makeDifferences(today: now, history: history).map(\.message) {
                for word in banned {
                    XCTAssertFalse(message.contains(word), "禁止語「\(word)」が含まれています: \(message)")
                }
            }
        }
    }
}
