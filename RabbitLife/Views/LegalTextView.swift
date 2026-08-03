import SwiftUI

struct LegalTextView: View {

    enum Document {
        case terms
        case privacy

        var title: String {
            switch self {
            case .terms: return "利用規約"
            case .privacy: return "プライバシーポリシー"
            }
        }

        var body: String {
            switch self {
            case .terms: return Self.termsText
            case .privacy: return Self.privacyText
            }
        }

        private static let termsText = """
        本規約は、Rabbit Life（以下「本アプリ」）の利用条件を定めるものです。本アプリをご利用いただいた時点で、本規約に同意したものとみなします。

        1. 本アプリの目的
        本アプリは、うさぎの日々の記録から「昨日との違い」を見つけて表示することを目的としています。

        2. 医療行為との関係
        本アプリは獣医療行為、診断、治療、その予測を行うものではありません。本アプリが表示する内容は診断結果ではなく、飼い主が変化に気づくための参考情報です。うさぎの健康について判断が必要な場合は、必ずかかりつけの動物病院へご相談ください。

        3. 免責
        本アプリの利用または利用不能によって生じたいかなる損害についても、開発者は責任を負いません。

        4. データの取り扱い
        本アプリが扱うデータはすべて利用者の端末内に保存されます。詳細はプライバシーポリシーをご確認ください。

        5. 規約の変更
        本規約は予告なく変更されることがあります。変更後の規約は、本アプリ内に表示された時点から効力を生じます。
        """

        private static let privacyText = """
        Rabbit Life（以下「本アプリ」）における個人情報およびデータの取り扱いについて説明します。

        1. 収集する情報
        本アプリは、利用者に関する個人情報を一切収集しません。氏名、メールアドレス、アカウント情報の登録も求めません。

        2. 記録データの保存場所
        うさぎの名前、日々の記録、写真、メモ、イベントなど、本アプリに入力されたすべてのデータは、利用者の端末内にのみ保存されます。

        3. 外部送信
        本アプリはネットワーク通信を行いません。入力されたデータが開発者や第三者へ送信されることはありません。

        4. 解析・広告
        本アプリは、アクセス解析ツール、広告配信、トラッキングを一切利用しません。

        5. バックアップ
        設定で「iCloudバックアップに含める」をONにした場合、記録データは端末のiCloudバックアップの一部として保存されます。これはAppleの提供する端末バックアップの仕組みによるもので、開発者がデータへアクセスすることはありません。

        6. 写真へのアクセス
        写真を添付する場合にのみ、利用者が選択した写真を読み込みます。写真ライブラリ全体へアクセスすることはありません。

        7. データの削除
        本アプリを端末から削除すると、保存されていたすべてのデータも削除されます。

        8. お問い合わせ
        本ポリシーに関するお問い合わせは、App Storeの製品ページに記載の連絡先までお願いいたします。
        """
    }

    let document: Document

    var body: some View {
        ScrollView {
            Text(document.body)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
