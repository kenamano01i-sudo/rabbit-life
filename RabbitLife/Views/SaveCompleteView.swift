import SwiftUI

/// 保存直後に「今日見つかった変化」を返す画面（画面設計 §6）。
/// 入力の見返りをここで返すのが Rabbit Life の体験の中心。
struct SaveCompleteView: View {

    let drafts: [DifferenceDraft]
    let rabbitName: String

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false

    private var daily: [DifferenceDraft] {
        drafts.filter { $0.compareType == .yesterday }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var recent: [DifferenceDraft] {
        drafts.filter { $0.compareType != .yesterday }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var encouragement: (emoji: String, text: String) {
        DifferenceEngine.encouragement(for: drafts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.green)
                            Text("保存しました").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if !daily.isEmpty {
                        Card(title: "今日見つかった変化") {
                            VStack(spacing: 14) {
                                ForEach(daily) { draft in
                                    DifferenceRow(draft: draft)
                                }
                            }
                        }
                        .offset(y: revealed ? 0 : 24)
                        .opacity(revealed ? 1 : 0)
                    }

                    if !recent.isEmpty {
                        Card(title: "最近の変化") {
                            VStack(spacing: 14) {
                                ForEach(recent) { draft in
                                    DifferenceRow(draft: draft, showTitle: false)
                                }
                            }
                        }
                        .offset(y: revealed ? 0 : 24)
                        .opacity(revealed ? 1 : 0)
                    }

                    Card {
                        VStack(spacing: 8) {
                            Text(encouragement.emoji).font(.largeTitle)
                            Text(encouragement.text)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .offset(y: revealed ? 0 : 24)
                    .opacity(revealed ? 1 : 0)

                    Text("このアプリは診断を行いません。\n心配な場合はかかりつけの動物病院へご相談ください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(rabbitName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
                revealed = true
            }
        }
    }
}
