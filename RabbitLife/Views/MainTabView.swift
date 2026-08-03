import SwiftUI
import SwiftData

struct MainTabView: View {

    let rabbit: Rabbit

    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = Tab.home
    /// 日付が変わってもホームが古い日を見続けないように保持する。
    @State private var today = Date().startOfDayRL

    enum Tab: Hashable {
        case home, calendar, record, timeline, settings
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(rabbit: rabbit, day: today, selection: $selection)
                .id(today)
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(Tab.home)

            CalendarView(rabbit: rabbit)
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(Tab.calendar)

            RecordView(rabbit: rabbit, day: today)
                .id(today)
                .tabItem { Label("今日の記録", systemImage: "plus.circle.fill") }
                .tag(Tab.record)

            TimelineView(rabbit: rabbit)
                .tabItem { Label("タイムライン", systemImage: "book.fill") }
                .tag(Tab.timeline)

            SettingsView(rabbit: rabbit)
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let current = Date().startOfDayRL
            if current != today { today = current }
        }
    }
}
