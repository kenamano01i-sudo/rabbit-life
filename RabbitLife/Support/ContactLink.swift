import Foundation

/// かかりつけ医の住所・電話番号を、マップアプリや電話アプリに渡すURLに変換する。
enum ContactLink {

    /// クエリ文字列に入れると意味を持ってしまう記号は、住所の一部でもエスケープする。
    private static let addressAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&+=?#")
        return set
    }()

    /// 住所をマップアプリで開くURL。住所が空なら nil。
    static func maps(address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: addressAllowed)
        else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    /// 電話番号を発信するURL。「03-1234-5678」のような表記ゆれを許容するため数字と + 以外は落とす。
    static func tel(phone: String) -> URL? {
        let dialable = phone.filter { $0.isNumber || $0 == "+" }
        guard !dialable.isEmpty else { return nil }
        return URL(string: "tel:\(dialable)")
    }
}
