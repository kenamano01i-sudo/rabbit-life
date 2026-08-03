import SwiftUI
import SwiftData

struct CalendarView: View {

    let rabbit: Rabbit

    @State private var month = Date().startOfDayRL
    @State private var selectedDay: Date?

    private let calendar = Calendar.rabbitLife

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    RabbitSwitcher(current: rabbit)

                    Card {
                        VStack(spacing: 14) {
                            monthHeader
                            weekdayHeader
                            MonthGrid(rabbit: rabbit, month: month, selectedDay: $selectedDay)
                                .id(month)
                        }
                    }

                    legend

                    if let selectedDay {
                        DayDetailCard(rabbit: rabbit, day: selectedDay)
                            .id(selectedDay)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("前の月")

            Spacer()
            Text(DateText.yearMonth(month))
                .font(.headline)
                .monospacedDigit()
            Spacer()

            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("次の月")
                .disabled(isCurrentMonth)
        }
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(["月", "火", "水", "木", "金", "土", "日"], id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var legend: some View {
        Card(title: "色の意味") {
            VStack(alignment: .leading, spacing: 8) {
                legendRow(.green, "変化なし")
                legendRow(.yellow, "少し変化")
                legendRow(.red, "気になる変化")
            }
        }
    }

    private func legendRow(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func shiftMonth(_ value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        month = next
        selectedDay = nil
    }
}

// MARK: - 月グリッド

private struct MonthGrid: View {

    let rabbit: Rabbit
    let month: Date
    @Binding var selectedDay: Date?

    @Query private var differences: [Difference]

    private let calendar = Calendar.rabbitLife

    init(rabbit: Rabbit, month: Date, selectedDay: Binding<Date?>) {
        self.rabbit = rabbit
        self.month = month
        self._selectedDay = selectedDay

        let rabbitID = rabbit.id
        let start = Calendar.rabbitLife.date(
            from: Calendar.rabbitLife.dateComponents([.year, .month], from: month)
        ) ?? month.startOfDayRL
        let end = Calendar.rabbitLife.date(byAdding: .month, value: 1, to: start) ?? start.addingDays(31)

        _differences = Query(
            filter: #Predicate<Difference> { $0.rabbitID == rabbitID && $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\Difference.date, order: .forward)]
        )
    }

    /// 日付 → その日の最大レベル
    private var levelsByDay: [Date: DifferenceLevel] {
        Dictionary(grouping: differences, by: { $0.date })
            .compactMapValues { $0.map(\.level).max() }
    }

    var body: some View {
        let cells = makeCells()
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(cells.indices, id: \.self) { index in
                if let date = cells[index] {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let level = levelsByDay[date]
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date().startOfDayRL

        return Button {
            selectedDay = isSelected ? nil : date
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(isFuture ? .tertiary : .primary)
                Circle()
                    .fill(dotColor(level))
                    .frame(width: 8, height: 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isToday ? Color.accentColor : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityText(date, level))
    }

    private func dotColor(_ level: DifferenceLevel?) -> Color {
        guard let level else { return Color(.quaternaryLabel) }
        switch level {
        case .normal: return .green
        case .notice: return .yellow
        case .warning, .important: return .red
        }
    }

    private func accessibilityText(_ date: Date, _ level: DifferenceLevel?) -> String {
        let day = DateText.longDay(date)
        guard let level else { return "\(day)、記録なし" }
        switch level {
        case .normal: return "\(day)、変化なし"
        case .notice: return "\(day)、少し変化あり"
        case .warning, .important: return "\(day)、気になる変化あり"
        }
    }

    private func makeCells() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<range.count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}

// MARK: - 選択日の詳細

private struct DayDetailCard: View {

    let rabbit: Rabbit
    let day: Date

    @Query private var differences: [Difference]

    init(rabbit: Rabbit, day: Date) {
        self.rabbit = rabbit
        self.day = day

        let rabbitID = rabbit.id
        let start = day.startOfDayRL
        let end = start.addingDays(1)

        _differences = Query(
            filter: #Predicate<Difference> { $0.rabbitID == rabbitID && $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\Difference.sortOrder, order: .forward)]
        )
    }

    var body: some View {
        Card(title: DateText.longDay(day)) {
            if differences.isEmpty {
                Text("この日の記録はありません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 14) {
                    ForEach(differences) { difference in
                        DifferenceRow(difference: difference)
                    }
                }
            }
        }
    }
}
