import Foundation

// MARK: - 記録項目の選択肢

/// 「今日の記録」で選ぶ選択肢に共通のふるまい。
///
/// `rank` は選択肢の並び順（増えた／減ったの判定に使う）、
/// `concern` は「いつも通りからどれだけ離れているか」を表す。
/// concern は医療的な重症度ではなく、あくまで表示の優先度である。
protocol RecordOption: RawRepresentable, CaseIterable, Identifiable, Hashable where RawValue == String {
    var label: String { get }
    var concern: Int { get }
}

extension RecordOption {
    var id: String { rawValue }
}

extension RecordOption where AllCases == [Self] {
    /// 選択肢リスト内での位置。大きいほど「多い／大きい」側。
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

// MARK: - 食欲

enum Appetite: String, RecordOption {
    case normal
    case slightlyLess
    case half
    case notEating

    var label: String {
        switch self {
        case .normal: return "普通"
        case .slightlyLess: return "少し少ない"
        case .half: return "半分くらい"
        case .notEating: return "食べない"
        }
    }

    var concern: Int {
        switch self {
        case .normal: return 0
        case .slightlyLess: return 1
        case .half: return 2
        case .notEating: return 3
        }
    }
}

// MARK: - 飲水

enum WaterIntake: String, RecordOption {
    case less
    case normal
    case more

    var label: String {
        switch self {
        case .less: return "少ない"
        case .normal: return "普通"
        case .more: return "多い"
        }
    }

    var concern: Int {
        switch self {
        case .normal: return 0
        case .less, .more: return 1
        }
    }
}

// MARK: - うんち（量）

enum PoopAmount: String, RecordOption {
    case less
    case normal
    case more

    var label: String {
        switch self {
        case .less: return "少ない"
        case .normal: return "普通"
        case .more: return "多い"
        }
    }

    var concern: Int {
        switch self {
        case .less: return 2
        case .normal, .more: return 0
        }
    }
}

// MARK: - うんち（サイズ）

enum PoopSize: String, RecordOption {
    case small
    case normal
    case large

    var label: String {
        switch self {
        case .small: return "小さい"
        case .normal: return "普通"
        case .large: return "大きい"
        }
    }

    var concern: Int {
        switch self {
        case .small: return 2
        case .normal, .large: return 0
        }
    }
}

// MARK: - うんち（形）

enum PoopShape: String, RecordOption {
    case round
    case oblong
    case irregular

    var label: String {
        switch self {
        case .round: return "丸い"
        case .oblong: return "細長い"
        case .irregular: return "ばらつき"
        }
    }

    var concern: Int {
        switch self {
        case .round: return 0
        case .oblong, .irregular: return 1
        }
    }
}

// MARK: - 元気

enum ActivityLevel: String, RecordOption {
    case energetic
    case quiet
    case inactive

    var label: String {
        switch self {
        case .energetic: return "元気"
        case .quiet: return "少し静か"
        case .inactive: return "あまり動かない"
        }
    }

    var concern: Int {
        switch self {
        case .energetic: return 0
        case .quiet: return 1
        case .inactive: return 3
        }
    }
}

// MARK: - 性別

enum Sex: String, CaseIterable, Identifiable, Hashable {
    case male
    case female
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: return "男の子"
        case .female: return "女の子"
        case .unknown: return "不明"
        }
    }
}

// MARK: - イベント種別

enum EventType: String, CaseIterable, Identifiable, Hashable {
    case hospital
    case nailClip
    case brushing
    case toothTrim
    case moltStart
    case moltEnd
    case birthday
    case adoption
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hospital: return "病院"
        case .nailClip: return "爪切り"
        case .brushing: return "ブラッシング"
        case .toothTrim: return "歯切り"
        case .moltStart: return "換毛開始"
        case .moltEnd: return "換毛終了"
        case .birthday: return "誕生日"
        case .adoption: return "お迎え記念日"
        case .other: return "その他"
        }
    }

    var symbolName: String {
        switch self {
        case .hospital: return "cross.case.fill"
        case .nailClip: return "scissors"
        case .brushing: return "comb.fill"
        case .toothTrim: return "mouth.fill"
        case .moltStart: return "leaf.fill"
        case .moltEnd: return "leaf"
        case .birthday: return "gift.fill"
        case .adoption: return "house.fill"
        case .other: return "star.fill"
        }
    }
}
