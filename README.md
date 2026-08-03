# Rabbit Life

うさぎの「昨日との違い」だけを教えてくれる iOS アプリ。

仕様書 / データモデル設計書（v2.0, Difference モデル採用版）/ 画面設計書 に基づく MVP 実装です。

---

## ビルド方法

**macOS + Xcode 16 以降が必要です。** Windows ではビルドできません。

1. このフォルダごと Mac にコピーする
2. `RabbitLife.xcodeproj` を Xcode で開く
3. Signing & Capabilities で自分の Team を選ぶ
4. Bundle Identifier を `com.example.RabbitLife` から自分のものへ変更する
5. iPhone シミュレータまたは実機を選んで ⌘R

> プロジェクトは Xcode 16 の「file system synchronized group」を使っています。
> `RabbitLife/` 以下にファイルを追加すると自動でターゲットに含まれるため、`.pbxproj` の編集は不要です。

### コマンドラインでビルドする

共有スキームを同梱しているので、Xcode を開かずにビルドできます。

```
xcodebuild -project RabbitLife.xcodeproj -scheme RabbitLife \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

エラーだけを見たい場合:

```
xcodebuild ... build 2>&1 | grep -E 'error:|warning:'
```

### テストを動かす場合

テストターゲットは同梱していません（Xcode 側で1回だけ作業が必要）。

1. File ▸ New ▸ Target… ▸ **Unit Testing Bundle** を追加（名前は `RabbitLifeTests`）
2. Xcode が作ったテンプレートのファイルを削除し、同梱の `RabbitLifeTests/DifferenceEngineTests.swift` をそのターゲットへドラッグする
3. ⌘U

`DifferenceEngine` は SwiftData に依存しない純粋な値型なので、テストは永続化なしで動きます。

---

## 設計

```
DailyRecord（事実）
      │  保存
      ▼
DifferenceEngine
      │  昨日 / 7日 / 30日 / 前年 を比較
      ▼
Difference（気付き）  ←── Home / Calendar / 通知 はこれしか読まない
```

ホーム画面もカレンダーも `DailyRecord` を一切参照しません。表示のたびに再計算せず、保存時に一度だけ差分を作って保存します（データモデル設計 §9〜§12）。

### ファイル構成

| パス | 役割 |
|---|---|
| `Models/RecordOptions.swift` | 食欲・飲水・うんち・元気などの選択肢と「気になり度」 |
| `Models/DifferenceTypes.swift` | `DifferenceTarget` / `CompareType` / `DifferenceLevel` / `DifferenceColor` |
| `Models/Rabbit.swift` `DailyRecord.swift` `Event.swift` `Difference.swift` | SwiftData モデル |
| `Engine/DifferenceDraft.swift` | エンジンの入出力に使う値型（SwiftData 非依存） |
| `Engine/DifferenceEngine.swift` | **差分エンジン本体** |
| `Data/Repositories.swift` | Rabbit / DailyRecord / Event / Difference の取得・作成 |
| `Data/DifferenceService.swift` | 保存後の Difference 再生成 |
| `Services/` | 通知・CSV書き出し・バックアップ設定・アプリ設定 |
| `Views/` | 各画面 |
| `Components/Components.swift` | カード・差分行・選択チップ・写真フィールド |

`Difference` には `rabbitID` を非正規化して持たせています。SwiftData の `#Predicate` はリレーションをたどる条件が扱いにくいためです。

---

## 差分エンジンのルール

### 昨日との比較（`.yesterday`）
食欲・うんち・飲水・元気・体重の5項目。昨日の記録がない場合は7日前までさかのぼって「前回」と比較し、文言も「前回より」に変わります。

体重の判定：

| 変化 | レベル | 文言例 |
|---|---|---|
| ±5g 未満 | normal | 変化ありません |
| 増加 | normal / 50g以上で notice | ＋10g |
| 減少 25g 未満 | notice | －20g |
| 減少 25g 以上 | warning | 30g減っています |
| 減少 60g 以上 または 3% 以上 | important | 〜g減っています。心配な場合は… |

### ここ1週間（`.lastWeek`）
記録が途切れていない連続日のみを数えます（歯抜けの日があると連続扱いにしません）。

- 3日以上続けて食欲が少なめ
- 2日以上続けて食べない → important ＋ 受診をすすめる文言
- 直近4日で食欲が単調に低下 → 「徐々に食欲が低下しています」
- うんちの量・サイズ、元気の連続傾向

### 1か月前 / 去年（`.lastMonth` / `.lastYear`）
30日前（±5日）との体重比較、去年の同時期（±3日）の食欲・体重、去年の換毛開始（±14日）。

### イベント起点
換毛開始からの経過日数、前回の爪切りからの経過日数。

### 医療上の配慮
病名・診断名は生成しません。`important` のときだけ「心配な場合はかかりつけの動物病院へご相談ください。」を添えます。この方針は `DifferenceEngineTests.testNoDiagnosticVocabularyIsEverGenerated` で機械的に検査しています。

---

## 実装済みの画面（画面設計 §15 の MVP 全件）

スプラッシュ / 初回セットアップ / ホーム / 今日の記録 / 保存完了 / カレンダー / タイムライン / イベント登録 / プロフィール / 設定

加えて、利用規約とプライバシーポリシーの本文（雛形）、CSV 書き出しを入れています。

---

## 仕様との差分

意図的に変えた点・入れていない点です。

- **入力 UI をラジオボタンではなくチップにした。** 画面設計書は `○ 普通 / ○ 少し少ない` というリスト表記ですが、「30秒以内」を優先して1タップで選べる形にしています。Dynamic Type で文字が大きくなるとグリッドが折り返します。
- **PDF 書き出しは未実装。** 画面設計 §11 の設定画面には載っていますが、§16 では Version 1.1 扱いだったため MVP から外し、設定画面にも表示していません。CSV は実装済みです。
- **複数匹対応は未実装**（仕様書 §15 で Version 1.1）。データモデルは複数匹を持てる形になっているので、`RootView` の `rabbits.first` を切り替え UI に差し替えれば拡張できます。
- **Widget / Live Activity / Apple Watch は未実装**（Version 2.0）。`Difference` を読むだけで作れるよう、モデル側は準備済みです。
- **「iCloudバックアップ」設定の実体**は、SwiftData ストアを端末バックアップに含めるかどうかの切り替えです（`isExcludedFromBackup`）。CloudKit 同期はしていません。仕様書 §2 の「バックアップは iCloud バックアップのみ」に合わせています。
- **アプリアイコンは未収録。** `Assets.xcassets/AppIcon.appiconset` は空です。1024×1024 の画像を入れてください。

## 未検証の点

Windows 環境で作成しているため、**Xcode でのビルド・実行は未確認です。** 特に次の箇所は Mac で最初に確認してください。

- SwiftData の `#Predicate` を使ったクエリ（`Repositories.swift`、各 View の `@Query`）
- `PhotosPicker` からの画像読み込み
- 通知の許可フローと `UNCalendarNotificationTrigger`
