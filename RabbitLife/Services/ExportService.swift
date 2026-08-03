import Foundation

/// CSV書き出し。端末内でファイルを作り、共有シートに渡すだけ。送信はしない。
enum ExportService {

    /// カンマ・引用符・改行を含む値を CSV として安全にする。
    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func csv(rabbit: Rabbit, records: [DailyRecord]) -> String {
        let header = ["日付", "食欲", "飲水", "うんち量", "うんちサイズ", "うんち形", "元気", "体重(kg)", "メモ"]

        var lines = [header.map(escape).joined(separator: ",")]

        for record in records.sorted(by: { $0.date < $1.date }) {
            let weight = record.weight.map { String(format: "%.2f", $0) } ?? ""
            let columns = [
                DateText.numeric(record.date),
                record.appetite.label,
                record.water.label,
                record.poopAmount.label,
                record.poopSize.label,
                record.poopShape.label,
                record.activity.label,
                weight,
                record.memo
            ]
            lines.append(columns.map(escape).joined(separator: ","))
        }

        return lines.joined(separator: "\r\n")
    }

    /// 一時ディレクトリへ書き出して URL を返す。共有後は OS が掃除する。
    static func writeCSV(rabbit: Rabbit, records: [DailyRecord]) -> URL? {
        let safeName = rabbit.name.isEmpty ? "rabbit" : rabbit.name
        let fileName = "RabbitLife_\(safeName)_\(DateText.numeric(Date()).replacingOccurrences(of: "/", with: "-")).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Excel（日本語環境）で文字化けしないよう BOM を付ける。
        let body = "\u{FEFF}" + csv(rabbit: rabbit, records: records)

        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
