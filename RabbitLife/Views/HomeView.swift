import SwiftUI
import SwiftData

/// ホームは DailyRecord を一切読まない。Difference だけを表示する
/// （データモデル設計 §10 / §12）。
struct HomeView: View {

    let rabbit: Rabbit
    let day: Date
    @Binding var selection: MainTabView.Tab

    @Query private var differences: [Difference]
    @Query private var records: [DailyRecord]

    init(rabbit: Rabbit, day: Date, selection: Binding<MainTabView.Tab>) {
        self.rabbit = rabbit
        self.day = day
        self._selection = selection

        let rabbitID = rabbit.id
        let start = day.startOfDayRL
        let end = start.addingDays(1)

        _differences = Query(
            filter: #Predicate<Difference> { $0.rabbitID == rabbitID && $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\Difference.sortOrder, order: .forward)]
        )
        _records = Query(
            filter: #Predicate<DailyRecord> { $0.rabbitID == rabbitID && $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\DailyRecord.date, order: .forward)]
        )
    }

    private var hasRecordToday: Bool { !records.isEmpty }
    private var dailyDifferences: [Difference] { differences.filter { $0.compareType == .yesterday } }
    private var recentDifferences: [Difference] { differences.filter { $0.compareType != .yesterday } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    RabbitSwitcher(current: rabbit)

                    header

                    if hasRecordToday {
                        if !dailyDifferences.isEmpty {
                            Card(title: CompareType.yesterday.label) {
                                VStack(spacing: 14) {
                                    ForEach(dailyDifferences) { difference in
                                        DifferenceRow(difference: difference)
                                    }
                                }
                            }
                        }

                        if !recentDifferences.isEmpty {
                            Card(title: "最近の変化") {
                                VStack(spacing: 14) {
                                    ForEach(recentDifferences) { difference in
                                        DifferenceRow(difference: difference, showTitle: false)
                                    }
                                }
                            }
                        }

                        disclaimer
                    } else {
                        notRecordedCard
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView(rabbit: rabbit)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("プロフィール")
                }
            }
        }
    }

    // MARK: - パーツ

    private var header: some View {
        Card {
            HStack(alignment: .center, spacing: 12) {
                RabbitAvatar(photo: rabbit.photo, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(rabbit.name)
                        .font(.title3.weight(.semibold))
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryText: String {
        guard hasRecordToday else { return "今日の様子はまだ記録されていません。" }
        return DifferenceEngine.summary(for: differences, rabbitName: rabbit.name)
    }

    private var notRecordedCard: some View {
        Card {
            VStack(spacing: 12) {
                Text("🥕").font(.largeTitle)
                Text("今日の様子を記録すると、\n昨日との違いをお知らせします。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    selection = .record
                } label: {
                    Label("今日の記録をつける", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    /// 医療上の配慮（仕様書 §13）。診断はしない、という立場を常に見せる。
    @ViewBuilder
    private var disclaimer: some View {
        if (differences.map(\.level).max() ?? .normal) >= .warning {
            Text("このアプリは診断を行いません。心配な場合はかかりつけの動物病院へご相談ください。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
        }
    }
}
