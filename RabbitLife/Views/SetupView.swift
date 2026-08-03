import SwiftUI
import SwiftData

/// 初回セットアップ。ここで登録するのは1匹目だけ。
/// 2羽目以降は設定画面の「うさぎ」から追加する（上限 Rabbit.maxCount）。
struct SetupView: View {

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var draft = RabbitDraft()

    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Text("🐰").font(.system(size: 44))
                        Text("はじめまして")
                            .font(.title3.weight(.semibold))
                        Text("うさぎさんのことを教えてください。\nあとから設定で変更できます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                RabbitFormFields(draft: $draft)

                Section {
                    Text("記録は端末の中だけに保存されます。通信もアカウント登録もありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Rabbit Life")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("はじめる", action: save).disabled(!draft.canSave)
                }
            }
            .alert("保存できませんでした", isPresented: $showError) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        let rabbit = draft.insert(into: context)

        do {
            try context.save()
        } catch {
            // 保存できていないのに完了扱いにすると、データがないままメイン画面へ進んでしまう。
            // 挿入済みの下書きも破棄し、もう一度「はじめる」を押せる状態に戻す。
            context.rollback()
            errorMessage = error.localizedDescription
            showError = true
            return
        }

        settings.hasCompletedSetup = true
        settings.selectedRabbitID = rabbit.id.uuidString

        let name = rabbit.name
        Task {
            await NotificationManager.shared.syncDailyReminder(with: settings, rabbitNames: [name])
        }
    }
}
