import SwiftUI
import SwiftData

/// 写真とできごと中心の振り返り画面（画面設計 §8）。
struct TimelineView: View {

    let rabbit: Rabbit

    @Environment(\.modelContext) private var context
    @Query private var events: [Event]
    @Query private var records: [DailyRecord]

    @State private var showEventEditor = false

    @State private var errorMessage: String?
    @State private var showError = false

    init(rabbit: Rabbit) {
        self.rabbit = rabbit
        let rabbitID = rabbit.id

        _events = Query(
            filter: #Predicate<Event> { $0.rabbitID == rabbitID },
            sort: [SortDescriptor(\Event.date, order: .reverse)]
        )
        _records = Query(
            filter: #Predicate<DailyRecord> { $0.rabbitID == rabbitID },
            sort: [SortDescriptor(\DailyRecord.date, order: .reverse)]
        )
    }

    private var items: [TimelineItem] {
        let eventItems = events.map(TimelineItem.event)
        // 写真かメモがある日だけタイムラインに載せる。ただの数値記録は載せない。
        let recordItems = records
            .filter { $0.photo != nil || !$0.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(TimelineItem.record)
        return (eventItems + recordItems).sorted { $0.date > $1.date }
    }

    private var groupedByYear: [(year: String, items: [TimelineItem])] {
        let groups = Dictionary(grouping: items) { DateText.year($0.date) }
        return groups
            .map { (year: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    RabbitSwitcher(current: rabbit)

                    if items.isEmpty {
                        EmptyStateView(
                            systemImage: "book",
                            title: "まだできごとがありません",
                            message: "病院・爪切り・換毛などを記録すると、\nここに並びます。"
                        )
                    } else {
                        ForEach(groupedByYear, id: \.year) { group in
                            Text(group.year)
                                .font(.title3.weight(.semibold))
                                .padding(.top, 4)

                            ForEach(group.items) { item in
                                TimelineRow(item: item)
                                    .contextMenu {
                                        if case .event(let event) = item {
                                            Button("削除", role: .destructive) {
                                                delete(event)
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("タイムライン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEventEditor = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("できごとを追加")
                }
            }
            .sheet(isPresented: $showEventEditor) {
                EventEditView(rabbit: rabbit)
            }
            .alert("削除できませんでした", isPresented: $showError) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func delete(_ event: Event) {
        context.delete(event)

        do {
            try context.save()
        } catch {
            // delete はメモリ上に適用済みなので、戻さないと画面からは消えたまま
            // 次回起動時に復活する。取り消してから知らせる。
            context.rollback()
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - 行

enum TimelineItem: Identifiable {

    case event(Event)
    case record(DailyRecord)

    var id: String {
        switch self {
        case .event(let event): return "event-\(event.id.uuidString)"
        case .record(let record): return "record-\(record.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .event(let event): return event.date
        case .record(let record): return record.date
        }
    }
}

private struct TimelineRow: View {

    let item: TimelineItem

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Text(DateText.shortDay(item.date))
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    switch item {
                    case .event(let event):
                        Label(event.displayTitle, systemImage: event.type.symbolName)
                            .font(.subheadline.weight(.semibold))
                        if !event.memo.isEmpty {
                            Text(event.memo).font(.footnote).foregroundStyle(.secondary)
                        }
                        photo(event.photo)

                    case .record(let record):
                        photo(record.photo)
                        if !record.memo.isEmpty {
                            Text(record.memo).font(.subheadline)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func photo(_ data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("写真")
        }
    }
}
