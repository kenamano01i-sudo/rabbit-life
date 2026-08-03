import SwiftUI
import SwiftData

struct RootView: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Rabbit.createdAt, order: .forward) private var rabbits: [Rabbit]

    @State private var showSplash = true

    /// 選択中のうさぎ。削除された ID が残っていることもあるので、
    /// 実在しなければ先頭に戻す。
    private var selectedRabbit: Rabbit? {
        if let id = settings.selectedRabbitID,
           let match = rabbits.first(where: { $0.id.uuidString == id }) {
            return match
        }
        return rabbits.first
    }

    var body: some View {
        ZStack {
            if let rabbit = selectedRabbit {
                // ここで .id を付けるとタブ選択ごと作り直されてホームに戻ってしまう。
                // 作り直しは MainTabView 内の各画面に任せる。
                MainTabView(rabbit: rabbit)
            } else {
                SetupView()
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let names = rabbits.map(\.name)
            Task {
                await NotificationManager.shared.syncDailyReminder(
                    with: settings,
                    rabbitNames: names
                )
            }
        }
    }
}

struct SplashView: View {

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("🐰")
                    .font(.system(size: 64))
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                Text("Rabbit Life")
                    .font(.title2.weight(.semibold))
                Text("昨日との違いが、一番大切。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rabbit Life。昨日との違いが、一番大切。")
    }
}
