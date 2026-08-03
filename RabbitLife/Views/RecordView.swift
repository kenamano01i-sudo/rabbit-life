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

    /// 読み込み直後の値。うさぎを切り替えるとき、入力途中かどうかの判定に使う。
    @State private var loadedSnapshot: Snapshot?
    /// 入力途中に切り替えようとした先。確認ダイアログの表示条件も兼ねる。
    @State private var pendingRabbit: Rabbit?

    @State private var isLoaded = false
    @State private var isSaving = false
    @State private var resultDrafts: [DifferenceDraft] = []
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var showError = false

    @FocusState private var weightFocused: Bool

    /// 入力欄の中身をまとめて比較するための値。
    private struct Snapshot: Equatable {
        var appetite: Appetite
        var water: WaterIntake
        var poopAmount: PoopAmount
        var poopSize: PoopSize
        var poopShape: PoopShape
        var activity: ActivityLevel
        var weightText: String
        var memo: String
        var photo: Data?
    }

    private var currentSnapshot: Snapshot {
        Snapshot(
            appetite: appetite,
            water: water,
            poopAmount: poopAmount,
            poopSize: poopSize,
            poopShape: poopShape,
            activity: activity,
            weightText: weightText,
            memo: memo,
            photo: photo
        )
    }

    /// 読み込み時から変わっていれば、まだ保存していない入力がある。
    private var hasUnsavedChanges: Bool {
        guard let loadedSnapshot else { return false }
        return currentSnapshot != loadedSnapshot
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    RabbitSwitcher(current: rabbit) { candidate in
                        // 切り替えると画面が作り直され、入力途中の内容は失われる。
                        guard hasUnsavedChanges else { return true }
                        pendingRabbit = candidate
                        return false
                    }

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
        .confirmationDialog(
            pendingRabbit.map { "\($0.name)に切り替えますか？" } ?? "",
            isPresented: Binding(get: { pendingRabbit != nil }, set: { if !$0 { pendingRabbit = nil } }),
            titleVisibility: .visible
        ) {
            Button("切り替える", role: .destructive) {
                if let target = pendingRabbit {
                    settings.selectedRabbitID = target.id.uuidString
                }
                pendingRabbit = nil
            }
            Button("入力を続ける", role: .cancel) { pendingRabbit = nil }
        } message: {
            Text("入力中の内容は保存されません。")
        }
    }

    // MARK: - 読み込み

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true

        // 既存の記録がない場合も、初期値を基準として控えておく。
        defer { loadedSnapshot = currentSnapshot }

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

            // 保存できたので、以後の切り替えでは未保存扱いにしない。
            loadedSnapshot = currentSnapshot

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
