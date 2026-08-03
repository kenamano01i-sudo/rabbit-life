import SwiftUI
import SwiftData
import PhotosUI

// MARK: - カード

/// 角丸カード。余白を広く、色は控えめに（画面設計 §3）。
struct Card<Content: View>: View {

    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 差分の1行

struct DifferenceRow: View {

    let icon: String
    let title: String?
    let message: String
    let level: DifferenceLevel
    let color: DifferenceColor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color.swiftUIColor)
                .frame(width: 28, height: 28)
                .background(color.swiftUIColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                Text(message)
                    .font(title == nil ? .subheadline : .footnote)
                    .foregroundStyle(level == .normal ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if level > .normal {
                // 色だけに依存しない（画面設計 §14）
                Image(systemName: level >= .warning ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(color.swiftUIColor)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, message, level.accessibilityLabel].compactMap { $0 }.joined(separator: "、"))
    }
}

extension DifferenceRow {
    init(difference: Difference, showTitle: Bool = true) {
        self.init(
            icon: difference.icon,
            title: showTitle ? difference.target.label : nil,
            message: difference.message,
            level: difference.level,
            color: difference.color
        )
    }

    init(draft: DifferenceDraft, showTitle: Bool = true) {
        self.init(
            icon: draft.icon,
            title: showTitle ? draft.target.label : nil,
            message: draft.message,
            level: draft.level,
            color: draft.color
        )
    }
}

// MARK: - 選択肢ピッカー

/// 30秒で入力を終えるため、1タップで選べるチップ形式にしている。
struct OptionPicker<Option: RecordOption>: View where Option.AllCases == [Option] {

    let title: String
    var systemImage: String? = nil
    @Binding var selection: Option

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(title).font(.subheadline.weight(.semibold))
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(.secondary)
                }
            }

            // Dynamic Type で文字が大きくなっても折り返せるようにグリッドで並べる。
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                chips
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var chips: some View {
        ForEach(Option.allCases) { option in
            let isSelected = option == selection
            Button {
                selection = option
            } label: {
                Text(option.label)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        isSelected ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                    )
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }
    }
}

// MARK: - 写真

struct PhotoField: View {

    let label: String
    @Binding var data: Data?
    @State private var item: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("選択中の写真")

                Button("写真を削除", role: .destructive) {
                    self.data = nil
                    item = nil
                }
                .font(.footnote)
            }

            PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                Label(data == nil ? label : "写真を変更", systemImage: "camera")
                    .font(.subheadline)
            }
        }
        .task(id: item) {
            guard let item else { return }
            guard let loaded = try? await item.loadTransferable(type: Data.self) else { return }
            data = ImageSupport.normalized(loaded) ?? loaded
        }
    }
}

// MARK: - うさぎのアイコン

struct RabbitAvatar: View {

    let photo: Data?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.accentColor.opacity(0.15)
                    Text("🐰").font(.system(size: size * 0.5))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

// MARK: - うさぎの切り替え

/// うさぎの切り替えタブ。ホーム・カレンダー・今日の記録・タイムラインの先頭に置く。
/// 1羽でも出して、置き場所を常に一定にしておく。
struct RabbitSwitcher: View {

    /// 現在表示しているうさぎ。
    let current: Rabbit

    /// 切り替え前に確認したい画面が渡す。false を返すと切り替えを行わない
    /// （確認ダイアログの表示など、後始末は呼び出し側の責任）。
    var shouldSwitch: ((Rabbit) -> Bool)? = nil

    @Environment(AppSettings.self) private var settings
    @Query(sort: \Rabbit.createdAt, order: .forward) private var rabbits: [Rabbit]

    var body: some View {
        // 名前が長い場合や Dynamic Type で大きい場合に備えて横スクロールにする。
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(rabbits) { candidate in
                    let isSelected = candidate.id == current.id
                    Button {
                        guard !isSelected else { return }
                        guard shouldSwitch?(candidate) ?? true else { return }
                        settings.selectedRabbitID = candidate.id.uuidString
                    } label: {
                        HStack(spacing: 6) {
                            RabbitAvatar(photo: candidate.photo, size: 24)
                            Text(candidate.name)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                        )
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("表示するうさぎ")
    }
}

// MARK: - 空状態

struct EmptyStateView: View {

    let systemImage: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
