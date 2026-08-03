import SwiftUI
import SwiftData

/// 30秒以内で終える入力画面（画面設計 §5）。
struct RecordView: View {

    let rabbit: Rabbit
    let day: Date

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var appetite = Appetite.normal
    @State private var water = WaterIntake.normal
    @State private var poopAmount = PoopAmount.normal
    @State private var poopSize = PoopSize.normal
    @State private var poopShape = PoopShape.round
    @State private var activity = ActivityLevel.energetic
    @State private var weightText = ""
    @State private var memo = ""
    @State private var photo: Data?

    @State private var isLoaded = false
    @State private var isSaving = false
    @State private var resultDrafts: [DifferenceDraft] = []
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var showError = false

    @FocusState private var weightFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("今日の様子").font(.title3.weight(.semibold))
                            Text(DateText.longDay(day))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Card {
                        OptionPicker(title: "食欲", systemImage: "fork.knife", selection: $appetite)
                    }

                    Card {
                        OptionPicker(title: "飲水", systemImage: "drop.fill", selection: $water)
                    }

                    Card(title: "うんち") {
                        VStack(alignment: .leading, spacing: 16) {
                            OptionPicker(title: "量", selection: $poopAmount)
                            OptionPicker(title: "サイズ", selection: $poopSize)
                            OptionPicker(title: "形", selection: $poopShape)
                        }
                    }

                    Card {
                        OptionPicker(title: "元気", systemImage: "figure.run", selection: $activity)
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("体重（任意）", systemImage: "scalemass.fill")
                                .font(.subheadline.weight(.semibold))
                            HStack {
                                TextField("1.82", text: $weightText)
                                    .keyboardType(.decimalPad)
                                    .focused($weightFocused)
                                    .textFieldStyle(.roundedBorder)
                                Text("kg").foregroundStyle(.secondary)
                            }
                        }
                    }

                    Card {
                        PhotoField(label: "写真を追加（1日1枚）", data: $photo)
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("メモ（任意）", systemImage: "square.and.pencil")
                                .font(.subheadline.weight(.semibold))
                            TextField("気になったことがあれば", text: $memo, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Button(action: save) {
                        Text(isSaving ? "保存中…" : "保存")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("今日の記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { weightFocused = false }
                }
            }
        }
        .task { load() }
        .sheet(isPresented: $showResult) {
            SaveCompleteView(drafts: resultDrafts, rabbitName: rabbit.name)
        }
        .alert("保存できませんでした", isPresented: $showError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 読み込み

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true

        let repository = DailyRecordRepository(context: context)
        guard let existing = try? repository.record(for: rabbit, on: day) else { return }

        appetite = existing.appetite
        water = existing.water
        poopAmount = existing.poopAmount
        poopSize = existing.poopSize
        poopShape = existing.poopShape
        activity = existing.activity
        memo = existing.memo
        photo = existing.photo
        if let weight = existing.weight {
            weightText = String(format: "%.2f", weight)
        }
    }

    // MARK: - 保存

    private func save() {
        isSaving = true
        weightFocused = false

        do {
            let repository = DailyRecordRepository(context: context)
            let record = try repository.upsert(for: rabbit, on: day)

            record.appetite = appetite
            record.water = water
            record.poopAmount = poopAmount
            record.poopSize = poopSize
            record.poopShape = poopShape
            record.activity = activity
            record.weight = parsedWeight()
            record.memo = memo
            record.photo = photo
            record.updatedAt = Date()

            try context.save()

            // 保存 → DifferenceEngine 起動 → Difference 生成（データモデル設計 §9）
            let service = DifferenceService(context: context)
            let drafts = try service.regenerate(for: rabbit, on: day)
            try service.regenerateFollowingDays(for: rabbit, from: day)

            resultDrafts = drafts
            showResult = true

            Task {
                await NotificationManager.shared.notifyIfNeeded(drafts: drafts, settings: settings)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSaving = false
    }

    private func parsedWeight() -> Double? {
        let normalized = weightText
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let value = Double(normalized), value > 0 else { return nil }
        return value
    }
}
