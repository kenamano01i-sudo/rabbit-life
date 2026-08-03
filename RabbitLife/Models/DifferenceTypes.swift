import Foundation
import SwiftUI

// MARK: - どの項目の変化か

enum DifferenceTarget: String, Codable, CaseIterable, Identifiable, Hashable {
    case appetite
    case water
    case poop
    case weight
    case activity
    case event

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appetite: return "食欲"
        case .water: return "飲水"
        case .poop: return "うんち"
        case .weight: return "体重"
        case .activity: return "元気"
        case .event: return "できごと"
        }
    }

    var symbolName: String {
        switch self {
        case .appetite: return "fork.knife"
        case .water: return "drop.fill"
        case .poop: return "circle.grid.2x2.fill"
        case .weight: return "scalemass.fill"
        case .activity: return "figure.run"
        case .event: return "calendar"
        }
    }

    /// ホーム画面「昨日との比較」での並び順。
    var displayOrder: Int {
        switch self {
        case .appetite: return 0
        case .poop: return 1
        case .water: return 2
        case .activity: return 3
        case .weight: return 4
        case .event: return 5
        }
    }
}

// MARK: - 何と比較したか

enum CompareType: String, Codable, CaseIterable, Identifiable, Hashable {
    case yesterday
    case lastWeek
    case lastMonth
    case lastYear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yesterday: return "昨日との比較"
        case .lastWeek: return "この1週間"
        case .lastMonth: return "この1か月"
        case .lastYear: return "去年との比較"
        }
    }
}

// MARK: - 変化の重要度

enum DifferenceLevel: Int, Codable, CaseIterable, Comparable, Hashable {
    case normal = 0
    case notice = 1
    case warning = 2
    case important = 3

    static func < (lhs: DifferenceLevel, rhs: DifferenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var color: DifferenceColor {
        switch self {
        case .normal: return .green
        case .notice: return .yellow
        case .warning: return .orange
        case .important: return .red
        }
    }

    /// VoiceOver 用。色だけに依存しない表示のため（画面設計 §14）。
    var accessibilityLabel: String {
        switch self {
        case .normal: return "変化なし"
        case .notice: return "少し変化"
        case .warning: return "気になる変化"
        case .important: return "要注意の変化"
        }
    }
}

// MARK: - 表示色

enum DifferenceColor: String, Codable, CaseIterable, Hashable {
    case gray
    case green
    case yellow
    case orange
    case red

    var swiftUIColor: Color {
        switch self {
        case .gray: return .secondary
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }
}
