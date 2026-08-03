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

    /// 各画面の @Query は init で組み立てるため、うさぎや日付が変わったら
    /// 作り直さないと前の内容を見続けてしまう。
    /// 作り直しは画面ごとに行う（TabView 自体を作り直すと選択中のタブが
    /// ホームに戻ってしまうため）。
    private struct ContentKey: Hashable {
        let rabbitID: UUID
        let day: Date
    }

    private var key: ContentKey {
        ContentKey(rabbitID: rabbit.id, day: today)
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(rabbit: rabbit, day: today, selection: $selection)
                .id(key)
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(Tab.home)

            CalendarView(rabbit: rabbit)
                .id(rabbit.id)
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(Tab.calendar)

            RecordView(rabbit: rabbit, day: today)
                .id(key)
                .tabItem { Label("今日の記録", systemImage: "plus.circle.fill") }
                .tag(Tab.record)

            TimelineView(rabbit: rabbit)
                .id(rabbit.id)
                .tabItem { Label("タイムライン", systemImage: "book.fill") }
                .tag(Tab.timeline)

            SettingsView(rabbit: rabbit)
                .id(rabbit.id)
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
