# version-manager 設計ドキュメント

Swift製の汎用バージョン一括更新CLI。プロジェクトルートに `.appversion.yml` を置き、
`version-manager bump 1.18.0` の1コマンドで、プロジェクト内に散らばったバージョン文字列
（xcodeproj / Info.plist / Package.swift / fastlane設定 / README バッジ / CHANGELOG 等）を
検証付きで一括置換・リネーム・フック実行する。

兄弟プロジェクト [Egg](https://github.com/Ryu0118/Egg)（スキャフォールディングCLI）と
[ctxmv](https://github.com/Ryu0118/ctxmv)（セッション移行CLI）のharness・coding styleを完全踏襲する。
本ドキュメントは両リポジトリの実地調査（`/Users/ryu/Programing/Swift/MyLibrary/Egg`,
`/Users/ryu/Programing/Swift/MyLibrary/ctxmv`）を一次情報源とする。

---

## 1. ツール概要・コマンド体系

### 1.1 コマンド構成の判断: ctxmv型フラット構成を採用

Eggの2階層構造（`egg template <sub>` 配下に11サブコマンド）は「template管理」という
名前空間が必要だったための構成。version-managerのコマンドは4つで名前空間の必要がなく、
**ctxmv型のフラット構成**（ルートコマンド直下に全サブコマンド、`GlobalOptions` を
`@OptionGroup` で横断注入）を採用する。

```
version-manager bump <version>     # バージョンを一括更新（主要操作）
version-manager check              # 現在のファイル群が設定と整合しているか検証（CI向け）
version-manager current            # 現在のバージョンを表示
version-manager init               # .appversion.yml の雛形を生成
version-manager install-skills     # Agent Skillsをプロジェクトにインストール（詳細は§5.4）
```

ctxmvの `defaultSubcommand: MigrateCommand.self` + `shouldDisplay: false` パターンは
**採用しない**。ctxmvは「引数なし＝最頻出操作」が自明だったが、version-managerの `bump` は
破壊的操作であり、暗黙起動させるべきではない。`version-manager` 単体実行はヘルプを表示する。

### 1.2 各サブコマンド仕様

#### `bump <version>`

| 引数/オプション | 型 | 説明 |
|---|---|---|
| `<version>` | 必須引数 | 新バージョン文字列。`version.format`（後述）で検証 |
| `--dry-run` | Flag | 置換・リネーム・フックを実行せず、計画（diff）のみ表示 |
| `--json` | Flag | 計画・結果をJSONで出力（エージェント/CI連携用、Egg踏襲） |
| `--skip-hooks` | Flag | custom script hookをスキップ |
| `--force` | Flag | `check` 相当の事前整合性検証に失敗しても続行 |

動作フロー: config読込 → 新バージョン形式検証 → **全ファイルの置換/リネーム計画をメモリ上で構築**
→ 計画全体のバリデーション（0マッチのルールはエラー）→ diff表示 → 書き込み → post hook実行。
詳細は§4。

#### `check`

`.appversion.yml` の全ルールを現状ファイルに適用し、以下を検証して不整合なら非0で終了する:

- 各 `files[].pattern` が対象ファイルに **1回以上マッチする**（マッチ0＝設定が腐っている）
- 全マッチ箇所から抽出されたバージョン文字列が **すべて同一**（散らばったバージョンのズレ検知）
- 抽出されたバージョンが `version.format` に適合する
- `rename` ルールの対象ファイルが現バージョンのフォーマット済み名で存在する

CIの `test.yml` とは別に、リリースPRのゲートとして使える。`--json` 対応。

#### `current`

`source_of_truth`（後述、省略時は `files` の先頭ルール）からバージョンを抽出して表示。
`--json` で `{"version": "1.17.2"}` 形式。

#### `init`

カレントディレクトリに `.appversion.yml` の雛形（コメント付きサンプル）を書き出す。
既存ファイルがある場合はエラー（`--force` で上書き）。

#### `install-skills`

version-manager自身が持つAgent Skills（`.appversion.yml`の書き方ガイド等、§5.4参照）を
カレント/指定プロジェクトへ書き込む。Egg/ctxmvが依拠する外部ツール経由の受動配布
（`/plugin install`、`apm install`、`gh skill install`、`npx skills add`）とは別に、
version-managerバイナリ自身が完結して実行できる能動的な配布手段として用意する。
詳細な設計（書き込み先レイアウト・バイナリへの埋め込み方式）は §5.4 を参照。

### 1.3 GlobalOptions

```swift
struct GlobalOptions: ParsableArguments {
    @Option(name: [.short, .long], help: "Path to .appversion.yml")
    var config: String = ".appversion.yml"

    @Flag(name: .shortAndLong, help: "Verbose logging")
    var verbose = false
}
```

全サブコマンドが `@OptionGroup var globalOptions: GlobalOptions` で共有（ctxmv踏襲）。

### 1.4 出力方針

ctxmv踏襲: `swift-log` + `Rainbow` による `ColorLogHandler`（`Logger.Metadata` の
`color` キーで呼び出し側が色指定）。加えてEgg踏襲の `--json` モードを全サブコマンドに実装し、
非TTY環境（AIエージェント・CI）で対話やANSIカラーに依存しない。diff表示は
`+`/`-` 行を green/red で色付け、`--json` 時は構造化して返す。

---

## 2. `.appversion.yml` スキーマ設計

### 2.1 スキーマ全体像

```yaml
# .appversion.yml
version:
  # バージョン形式の検証ルール。既定は semver（X.Y.Z）
  format: semver              # semver | 任意のカスタム正規表現を pattern で指定
  strict: true                # semver時のみ有効（既定 true）。false でプレリリース/ビルドメタ（1.18.0-beta.1）を許容
  # format: pattern
  # pattern: '\d+\.\d+'       # 例: X.Y の2桁形式を使うプロジェクト向け

# バージョンの「正」とみなすルールID。current コマンドと check の基準に使う。省略時は files の先頭。
source_of_truth: xcodeproj

# 要件1・2: 置換対象ファイルと、バージョン部分をキャプチャする正規表現
files:
  - id: xcodeproj                              # ルール識別子（エラーメッセージ・source_of_truth 参照用）
    path: "*.xcodeproj/project.pbxproj"        # glob可（プロジェクトルート相対）
    pattern: 'MARKETING_VERSION = (\d+\.\d+\.\d+);'
    # pattern はキャプチャグループを必ず1個含む。グループ部分のみが新バージョンに置換される。
    # マッチが複数あれば全箇所置換（pbxprojはDebug/Releaseで2回以上出現するのが普通）。
    occurrences: all                           # all（既定）| 期待マッチ数の整数。数が合わなければエラー

  - id: readme-badge
    path: README.md
    pattern: 'badge/version-(\d+\.\d+\.\d+)-blue'

# 要件4: ファイル名自体のリネーム
renames:
  - id: version-xcconfig
    directory: Configs                         # 検索ディレクトリ
    # 現バージョン・新バージョンをファイル名フォーマットに変換するルール
    format: "{version}.xcconfig"               # {version} はtransform.run適用後のバージョン文字列
    transform:
      run: "echo \"$APPVERSION_VALUE\" | tr '.' '-'"   # "1.18.0" -> "1-18-0"
    # 旧: Configs/1-17-2.xcconfig -> 新: Configs/1-18-0.xcconfig にリネーム

# 要件5: custom script hook
hooks:
  pre:                                         # 置換前に実行。非0終了で bump 全体を中止
    - name: ensure-clean-worktree
      run: "git diff --quiet || (echo 'dirty worktree' && exit 1)"
  post:                                        # 全置換・リネーム成功後に実行
    - name: update-changelog
      run: "./scripts/insert-changelog-entry.sh"
    - name: regenerate
      run: "make generate-version-docs"
```

設計判断:

- **`pattern` はキャプチャグループ必須・グループのみ置換**。「行全体を置換」ではなく
  「バージョン文字列部分だけ差し替え」に限定することで、パターンの前後コンテキスト
  （`MARKETING_VERSION = ` 等）が誤置換ガードとして機能する。キャプチャグループが
  0個 or 2個以上の設定はConfigバリデーションでエラー（§4.2）。
- **`occurrences`**: 既定 `all`（1以上必須）。整数指定時はマッチ数の完全一致を要求。
  「1箇所のはずが0箇所」＝設定の腐敗、「2箇所のはずが3箇所」＝想定外の混入、を両方検知する。
- **`version.format` はsemver固定にしない**。DriveTrackerのようにmarketing version（semver）と
  build number（整数）が併存するプロジェクトでは、build number用に別の
  `.appversion.yml`（例: `.buildnumber.yml` を `--config` で指定）を置き、
  `format: pattern` + `pattern: '\d+'` で運用できる。1ツールで両方管理可能。
- **hookは `run` にシェルコマンド文字列**（`/bin/sh -c` 実行）。新旧バージョンは
  コマンド文字列への文字列補間ではなく**環境変数**で渡す:
  `APPVERSION_OLD` / `APPVERSION_NEW` / `APPVERSION_CONFIG_DIR`。
  補間方式はエスケープ問題とインジェクションの温床になるため採らない。
- **`renames[].transform` は固定オプション（`separator`等）を持たず、`run` のみ**。
  「区切り文字置換」で足りるプロジェクトばかりではない（ゼロ埋め、大文字化、
  独自エンコーディング等）ため、変換ロジックを version-manager 側に組み込まず
  丸ごとscript化する。契約は hooks と同じ `/bin/sh -c` 実行だが、入出力がhookと異なる:
  - 入力: 環境変数 `APPVERSION_VALUE`（変換対象のバージョン文字列。renameの計算では
    新バージョン、旧ファイル名解決の逆算では旧バージョンを渡す。他に `APPVERSION_OLD`/
    `APPVERSION_NEW`/`APPVERSION_CONFIG_DIR` も一貫して渡す）
  - 出力: **stdoutの1行（末尾改行はtrim）を変換結果として使う**。空出力・非0終了・
    複数行出力はエラー（`BumpPlanner` が握りつぶさずbump全体を失敗させる）
  - `transform` 省略時は `APPVERSION_VALUE` をそのまま使う（変換なし、素通し）
  - **重要な契約**: `transform.run` は新ファイル名を計算するために**計画構築フェーズ
    （`BumpPlanner`）で実行される**。つまり `--dry-run` でもこのscriptは実行される
    （`hooks.pre`/`hooks.post` は書き込みフェーズ前後にのみ実行され `--dry-run` では
    走らないのと対照的）。`check` コマンドも旧バージョン側のファイル名解決のために
    同様に実行する。よって `transform.run` は**副作用を持たない純粋な文字列変換のみ**を
    行うこと。ファイル書き込み・API呼び出し等の副作用が必要な処理は `hooks` 側に置く
    （この制約はConfigバリデーションでは検出できないため、CLAUDE.md/README双方に
    明記する運用上のルールとする）
- **パスはすべて `.appversion.yml` のあるディレクトリ相対**。絶対パスと `..` を含むパスは
  Configバリデーションでエラー（リポジトリ外への書き込み事故防止）。

### 2.2 サンプル1: DriveTracker級の複雑なケース

```yaml
version:
  format: semver

source_of_truth: xcodeproj

files:
  - id: xcodeproj
    path: "App/*.xcodeproj/project.pbxproj"
    pattern: 'MARKETING_VERSION = (\d+\.\d+\.\d+);'
    occurrences: all          # Debug/Release x iOS/watchOS/Widget で多数出現

  - id: fastlane-deliverfile
    path: fastlane/Deliverfile
    pattern: 'app_version\("(\d+\.\d+\.\d+)"\)'
    occurrences: 1

  - id: readme-badge
    path: README.md
    pattern: 'img\.shields\.io/badge/version-(\d+\.\d+\.\d+)-blue'
    occurrences: 1

  # 注意: CHANGELOGへの「新セクション挿入」は置換ルールでは表現しない
  # （既存見出しのバージョンを書き換えると履歴の改変になる）。post hookで行う（下記）。

renames:
  - id: version-xcconfig
    directory: App/Configs
    format: "Version-{version}.xcconfig"
    transform:
      run: "echo \"$APPVERSION_VALUE\" | tr '.' '-'"   # Version-1-17-2.xcconfig -> Version-1-18-0.xcconfig

hooks:
  pre:
    - name: clean-worktree
      run: "git diff --quiet"
  post:
    - name: insert-changelog-entry
      run: "./scripts/insert-changelog-entry.sh"   # $APPVERSION_NEW で新セクションを挿入
    - name: release-notes-placeholder
      run: "./scripts/create-release-notes.sh \"$APPVERSION_NEW\""
```

### 2.3 サンプル2: シンプルなSwiftPMライブラリ（Egg/ctxmv自身のようなCLI）

```yaml
version:
  format: semver

files:
  - id: version-swift
    path: Sources/MyToolCLI/Version.swift
    pattern: 'static let current = "(\d+\.\d+\.\d+)"'
    occurrences: 1

  - id: install-sh
    path: install.sh
    pattern: 'DEFAULT_VERSION="(\d+\.\d+\.\d+)"'
    occurrences: 1
```

（`renames` / `hooks` / `source_of_truth` は省略可。最小構成は `version` + `files` 1ルール。）

### 2.4 Codable型スケッチ

Eggの `Config`（ネスト型集約 + Yamsデコード）を踏襲:

```swift
// snake_caseキー（source_of_truth 等）はYAMLDecoderの keyDecodingStrategy: .convertFromSnakeCase でデコードする
package struct Config: Decodable, Sendable {
    package var version: VersionFormat
    package var sourceOfTruth: String?
    package var files: [FileRule]
    package var renames: [RenameRule]?
    package var hooks: Hooks?

    package struct VersionFormat: Decodable, Sendable {
        package var format: Format      // enum Format { case semver, pattern }
        package var pattern: String?    // format == .pattern のとき必須
        package var strict: Bool?       // semver時のみ有効。既定true。falseでプレリリース/ビルドメタ許容
    }

    package struct FileRule: Decodable, Sendable {
        package var id: String
        package var path: String        // glob
        package var pattern: String
        package var occurrences: Occurrences  // .all or .exactly(Int)。カスタムinit(from:)で
                                              // 文字列"all"/整数の多相デコード（EggのMacroDefaultValue方式）
    }

    package struct RenameRule: Decodable, Sendable {
        package var id: String
        package var directory: String
        package var format: String      // "{version}" プレースホルダ必須
        package var transform: Transform?

        package struct Transform: Decodable, Sendable {
            package var run: String     // hooksと同型。/bin/sh -c 実行、stdout1行を変換結果として使う
        }
    }

    package struct Hooks: Decodable, Sendable {
        package var pre: [Hook]?
        package var post: [Hook]?

        package struct Hook: Decodable, Sendable {
            package var name: String
            package var run: String
        }
    }
}
```

---

## 3. Package.swift 設計

3層構造（実行ファイル → CLI層 → Kit層）をEgg/ctxmvそのまま踏襲する。

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "version-manager",
    platforms: [
        .macOS(.v15),   // ctxmv同様に低め。RegexBuilderは13+で足りる。Linux対応余地も残す
    ],
    products: [
        .executable(name: "version-manager", targets: ["version-manager"]),
        .library(name: "VersionManagerKit", targets: ["VersionManagerKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.2"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.2"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.1"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.2.0"),
        .package(url: "https://github.com/tuist/FileSystem", from: "0.13.47"),          // Globのみ使用（Egg踏襲）
        .package(url: "https://github.com/Ryu0118/FileManagerProtocol", from: "0.1.0"), // FSモック化（Egg踏襲）
        .package(url: "https://github.com/Ryu0118/ProcessRunning", from: "0.2.1"),      // hook実行のモック化（Egg踏襲）
    ],
    targets: [
        .executableTarget(
            name: "version-manager",
            dependencies: ["VersionManagerCLI"],
        ),
        .target(
            name: "VersionManagerCLI",
            dependencies: [
                "VersionManagerKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),
        .target(
            name: "VersionManagerKit",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                .product(name: "Glob", package: "FileSystem"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Rainbow", package: "Rainbow"),
                .product(name: "FileManagerProtocol", package: "FileManagerProtocol"),
                .product(name: "ProcessRunning", package: "ProcessRunning"),
            ],
        ),
        .testTarget(
            name: "VersionManagerKitTests",
            dependencies: [
                "VersionManagerKit",
                .product(name: "Yams", package: "Yams"),
                .product(name: "FileManagerProtocol", package: "FileManagerProtocol"),
            ],
            exclude: ["Fixtures"],
        ),
        .testTarget(
            name: "VersionManagerCLITests",
            dependencies: ["VersionManagerCLI"],
        ),
    ]
)
```

依存選定の根拠:

| ライブラリ | 用途 | 出典 |
|---|---|---|
| swift-argument-parser 1.6.2 | CLIパーサー | Egg/ctxmv共通、バージョンも同一固定 |
| Yams | `.appversion.yml` デコード | EggのConfigLoader実績 |
| swift-log + Rainbow | 色付き構造化ログ（ColorLogHandler） | ctxmv実績 |
| FileSystem(Glob) | `files[].path` のglob展開 | EggがGlobプロダクトのみ使用する前例 |
| FileManagerProtocol | ファイルI/Oのプロトコル抽象化・テストモック | Egg実績（作者自作） |
| ProcessRunning | hookスクリプト実行の抽象化・テストモック | Egg実績（作者自作） |

semver検証・比較は**外部ライブラリに依存せず独自実装する**（`SemanticVersion` 型、§4.7参照）。
`Ryu0118/swift-semantic-versioning-parser` は仕様準拠が不完全（作者確認済み）のため採用しない。
SemVer 2.0.0仕様は正規表現1本と数値比較で閉じるスコープであり、外部依存を持つより
`VersionManagerKit/Versioning/` 内に閉じ込めて自前でテストし尽くす方が保守性が高い。

正規表現はEgg同様、標準の **RegexBuilder / `Regex(String)`**（外部依存なし）。
ユーザー定義patternは `try Regex(pattern)` の動的コンパイル、内部パターン（semverフォールバック、
`{version}` プレースホルダ検出等）はRegexBuilderで型安全に定義する。

Stencil / swift-interaction / MCP swift-sdk / swift-docc-plugin は**不要**（テンプレートエンジン・
対話プロンプト・MCP統合・DocC公開のいずれもversion-managerのスコープ外）。

アクセスレベル規約（ctxmv踏襲）: Kit/CLI内はデフォルト `package`。`public` は
executableエントリポイントの `@main` 型のみ。

---

## 4. アーキテクチャ設計

### 4.1 全体フロー（bump）

**plan-then-apply の2フェーズ構造**を中核に据える。第1フェーズで一切書き込まずに
全変更を計画としてメモリ上に構築・検証し、第2フェーズでのみ書き込む。

```
ConfigLoader ──> ConfigValidator ──> BumpPlanner ──────> PlanValidator ──> (diff表示 / --dry-runはここで終了)
 (Yams decode)    (静的検証)          (置換・リネーム計画)   (0マッチ検出等)
                                                                │
                                          HookRunner(pre) ──> PlanApplier ──> HookRunner(post)
                                                               (書き込み)
```

モジュール内サブディレクトリ構成（Sources/VersionManagerKit/）:

```
VersionManagerKit/
├── Config/          # Config.swift, ConfigLoader.swift, ConfigValidator*.swift, ConfigDecodingErrorFormatter.swift
├── Versioning/      # VersionFormatValidator.swift, VersionTransformer.swift
├── Planning/        # BumpPlanner.swift, BumpPlan.swift, PlanValidator.swift
├── Applying/        # PlanApplier.swift, DiffRenderer.swift
├── Hooks/           # HookRunner.swift
├── Runners/         # BumpRunner.swift, CheckRunner.swift, CurrentRunner.swift, InitRunner.swift,
│                    # InstallSkillsRunner.swift
├── Skills/          # SkillInstaller.swift, SkillAsset.swift
├── Generated/        # GeneratedSkills.swift（codegen生成物、.gitignore対象）
└── Internals/       # Regexes.swift, FileSystemAccess.swift ほか共通ユーティリティ
```

### 4.2 Config読み込み・バリデーション

- `ConfigLoader`: Yamsデコード。デコード失敗はEgg踏襲で `ConfigLoaderError`（`LocalizedError`）に
  ラップし、`ConfigDecodingErrorFormatter` で「どのキーが・なぜ」を人間可読に整形。
- `ConfigValidator`: Eggの **context付き単一エラーenum** パターンを踏襲し、
  セクションごとに `ConfigValidator+FilesValidator.swift` / `+RenamesValidator.swift` /
  `+HooksValidator.swift` のextension分割。

```swift
package enum ConfigValidatorError: Error, LocalizedError, Equatable {
    case invalidRegexPattern(ruleID: String, pattern: String, underlying: String)
    case captureGroupCountMismatch(ruleID: String, found: Int)   // 1個以外はエラー
    case pathEscapesProjectRoot(ruleID: String, path: String)    // 絶対パス・"..\" 禁止
    case duplicateRuleID(id: String)
    case missingVersionPlaceholder(ruleID: String, format: String) // renames.format に {version} が無い
    case unknownSourceOfTruth(id: String)
    case patternRequiredForCustomFormat
    // 各caseが「どのルールIDの・どのフィールドが」を必ず持つ（Egg踏襲）
    package var errorDescription: String? { ... }
}
```

静的検証項目: 正規表現のコンパイル可否 / キャプチャグループ数==1 / ルールID重複 /
パスのルート外脱出 / `{version}` プレースホルダ存在 / `source_of_truth` の参照整合 /
`format: pattern` 時の `pattern` 必須。

### 4.3 置換エンジン（Egg踏襲の逆順置換）

```swift
/// 1ファイル分の置換計画。適用前に全フィールドが確定している
package struct FileReplacementPlan: Sendable, Equatable {
    package let ruleID: String
    package let path: String                  // glob展開後の実パス
    package let matches: [MatchSlice]         // キャプチャグループのRange・旧値
    package let originalContent: String
    package let newContent: String            // 逆順置換済みの完成形
}
```

`BumpPlanner` の置換実装はEggの `resolveMacro` パターンをそのまま使う:
`content.matches(of: regex)` の結果を **`reversed()` で逆順ループ**し、各マッチの
キャプチャグループRangeに対して `replaceSubrange` する。後方から置換することで
前方マッチのインデックスがずれない。マッチごとに旧値を記録し、diff表示・検証に使う。

globは1パターンが複数ファイルにマッチしうる（例: 複数xcodeproj）。その場合はファイルごとに
`FileReplacementPlan` を作り、`occurrences` はファイル単位ではなく**ルール単位の合計**で検証する。

### 4.4 PlanValidator（安全性の要）

書き込み前に計画全体を検証し、1つでも失敗したら**何も書かない**:

- glob展開結果が0ファイル → エラー（`ruleID` 付き）
- ルールのマッチ合計が0 → エラー（**silent no-opの禁止**。この種のツールの典型的故障モード）
- `occurrences: N` 指定でマッチ数不一致 → エラー
- 抽出された旧バージョンがルール間で不一致 → 警告（`--force` なしではエラー。
  ズレたまま上書きすると原因が消えるため、まず `check` で気づかせる）
- 旧バージョン == 新バージョン → エラー（no-op bumpの検出）
- リネーム先ファイルが既に存在 → エラー

### 4.5 適用・ロールバック方針

- **基本方針: 事前検証で失敗を潰し、書き込みフェーズを最短化する**。書き込み自体は
  `FileReplacementPlan.newContent` を書くだけなので失敗要因はI/Oエラーのみ。
- 書き込みは「テンポラリファイルに書いてからrename」のアトミック書き込み
  （`FileManagerProtocol` 経由）。
- 途中失敗時のロールバック: `PlanApplier` は適用済みファイルの `originalContent` を保持しており、
  I/Oエラー発生時点で**適用済み分を逆順に原状復帰**してからエラー終了する。
  復帰自体も失敗した場合は、復帰できなかったファイル一覧を明示してユーザーに委ねる
  （git管理前提のツールなので `git checkout -- <files>` を案内）。
- リネームは全置換の後に実行（置換失敗時にリネームが済んでいる状態を作らない）。
- pre hookは計画検証後・書き込み前、post hookは全書き込み成功後。post hook失敗は
  ファイル変更をロールバック**しない**（hookは冪等でない外部作用を持ちうるため）。
  失敗したhook名と `APPVERSION_*` 環境変数を表示して手動リカバリ可能にする。

### 4.6 dry-run / diff表示

`--dry-run` は PlanValidator 通過後に `DiffRenderer` で計画を表示して終了する。
表示形式は unified diff 風（行単位、変更行の前後2行コンテキスト、Rainbowで着色）。
リネームは `rename: Configs/1-17-2.xcconfig -> Configs/1-18-0.xcconfig`、
hookは `would run: <name>` として列挙。`--json` 時は
`{"replacements": [...], "renames": [...], "hooks": [...]}` の構造化出力。
通常の `bump` でも書き込み前に同じdiffを表示する（確認プロンプトは設けない。
非TTY安全性を優先し、取り消しはgitに委ねる）。

### 4.7 バージョン検証・変換（独自SemVer実装）

外部ライブラリ（`Ryu0118/swift-semantic-versioning-parser`）は不採用。理由は §3 の通り
仕様準拠が不完全なため。`VersionManagerKit/Versioning/` に自前で実装し、
[SemVer 2.0.0](https://semver.org/) の仕様（特にpre-release/buildメタデータの構文と
比較順序）に忠実に、かつテストで仕様を丸ごと固定する。

```swift
/// SemVer 2.0.0 準拠のバージョン値型。`Comparable` で precedence 比較を提供する
package struct SemanticVersion: Equatable, Comparable, CustomStringConvertible, Sendable {
    package let major: Int
    package let minor: Int
    package let patch: Int
    package let preRelease: [PreReleaseIdentifier]   // ドット区切り識別子。空 = 正式版
    package let buildMetadata: String?                // 比較には一切関与しない（SemVer仕様通り）

    /// pre-release識別子は数値のみ("1"等)か英数字+ハイフンかで比較規則が変わる
    package enum PreReleaseIdentifier: Equatable, Sendable {
        case numeric(Int)        // 数値のみで構成される識別子は数値として比較
        case alphanumeric(String) // それ以外はASCII辞書順比較
    }

    package var description: String { ... }  // 元のフォーマットへ整形（buildMetadata含む）

    package static func < (lhs: Self, rhs: Self) -> Bool { ... }
    // 比較順序: major.minor.patch を数値比較 → 双方preRelease空なら等しい
    // → 一方だけpreRelease空なら「正式版 > pre-release版」 → 両方ありなら識別子を
    // 左から順に比較（数値<英数字、双方numericなら数値比較、双方alphanumericならASCII辞書順、
    // 片方が他方の接頭列なら短い方が小さい）。buildMetadataは比較に一切使わない。
}

package enum SemanticVersionParseError: Error, LocalizedError, Equatable {
    case invalidFormat(input: String)  // 正規表現に一致しない
    case componentOverflow(input: String, component: String)  // Int変換オーバーフロー
}

package extension SemanticVersion {
    /// SemVer 2.0.0 公式BNF準拠のRegexBuilder実装。
    /// 例: "1.18.0-beta.1+exp.sha.5114f85" を major/minor/patch/preRelease/buildMetadata に分解
    package init(parsing input: String) throws(SemanticVersionParseError) { ... }
}
```

- `VersionFormatValidator`: `format: semver` は `SemanticVersion(parsing:)` でパース検証
  （失敗 = フォーマット違反としてConfigValidatorErrorではなく実行時のバージョン検証エラーに変換）。
  `strict: false` のときのみ `preRelease` を許容し、既定の `strict: true` では
  `preRelease.isEmpty` を追加要求する（DriveTrackerのMARKETING_VERSIONのような
  正式版オンリー運用がデフォルト）。`format: pattern` は `^(?:pattern)$` の完全一致検証で、
  SemanticVersion型を経由しない（順序比較もできない単純フォーマットとして扱う）。
- ルール間の新旧バージョン比較（PlanValidatorの「旧バージョン==新バージョンならエラー」、
  および将来の `bump --major/--minor/--patch` 自動インクリメント）は `SemanticVersion: Comparable`
  を直接使う。`format: pattern` 運用では文字列の単純一致比較のみ行う（順序概念を仮定しない）。
- `VersionTransformer`: `renames[].transform.run` を `ProcessRunning` で実行し、
  `APPVERSION_VALUE`（変換対象のバージョン文字列。SemanticVersionの`description`から
  構築）を環境変数で渡してstdout1行を変換結果として受け取る。組み込みの変換オプション
  （`separator`等）は持たない。区切り文字置換・ゼロ埋め・大文字化など変換パターンは
  プロジェクトごとに違うため、外部scriptに委ねてversion-manager側では一切解釈しない
  （hooksと同じ設計方針、§2.1参照）。`transform` 省略時は入力をそのまま素通しする。

独自実装のテストは §7.2 のパラメータ化テストに加え、SemVer 2.0.0仕様書の
[precedence比較の公式例](https://semver.org/#spec-item-11)
（`1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0`）
をそのままテストケースとして固定し、仕様逸脱を将来のリグレッションとして検知できるようにする。

---

## 5. 開発ハーネスの移植計画

方針: **ctxmvをベースに、install.sh と .swiftlint.yml の厳格さはEgg/ctxmvの良い方を採る**。
MCP統合・DocCは行わないが、**skill/plugin配布はEgg方式を移植する**（§1.2 `install-skills`、
§5.4）。両者は独立の判断——「Eggの5配布経路（Claude Code plugin marketplace / Codex plugin /
APM / `gh skill` / `npx skills`）に対応するリポジトリ構造を持つこと」と「version-manager自身が
能動的にskillファイルを書き込む `install-skills` コマンドを持つこと」は積み重ねであり、
後者はEggにもctxmvにも前例がない新規機能として設計する。

### 5.1 そのまま流用（コピーして名前だけ置換）

| ファイル | 出典 | 備考 |
|---|---|---|
| `.claude/settings.json` | Egg/ctxmv（完全同一） | そのまま |
| `.claude/hooks/pre-commit-lint.sh` | 同上 | そのまま |
| `.claude/hooks/post-edit-lint.sh` | 同上 | そのまま |
| `.claude/hooks/gitnagg-check.sh` | 同上 | そのまま |
| `.codex/hooks.json` + `.codex/hooks/*.sh` | 同上 | そのまま |
| `.githooks/pre-commit` | ctxmv | gitleaks→swiftformat→再stage→swiftlint --strict→docsync check |
| `scripts/nest.sh` / `scripts/setup-hooks.sh` | ctxmv | そのまま |
| `Makefile` | ctxmv | `install-commands/format/lint/format-lint/hooks/test/check` の7ターゲット |
| `nestfile.yaml` | ctxmv | SwiftFormat 0.62.1 / SwiftLint 0.65.0 / gitnagg 0.3.0 / docsync 0.3.1 をchecksum固定。my-swift-linterは当面除外（§5.3） |
| `.gitnagg.yml` | Egg/ctxmv（完全同一） | 200行/6ファイルerror、120行/3ファイルwarning |
| `.mise.toml` | 同上 | `[tools] gitleaks = "latest"` のみ |
| `.swiftlint.yml` | **ctxmv**（厳格版） | opt_in 30項目超・閾値付き。作者の最新意図 |
| `.swiftformat` | ctxmv | `--swiftversion 6.2` に変更、他はそのまま |
| `install.sh` | **Egg**（新しい方） | SHA256チェックサム検証あり。バイナリ名を `version-manager` に |
| `LICENSE` | 同上 | MIT |
| `.claude-plugin/marketplace.json` | Egg | `name`/`plugins[].source` を `version-manager` に |
| `.claude/plugins/version-manager/.claude-plugin/plugin.json` | Egg | keywords等を差し替え。**MCP無しなので `.mcp.json` は置かない** |
| `plugins/version-manager/.codex-plugin/plugin.json` | Egg | 同上。`mcpServers` フィールドは省略（Egg版は含むが本ツールは非対象） |
| `apm.yml` | Egg | `includes:` は §5.4 で配布するSKILL.md群を指す |

### 5.2 構成を踏襲して新規作成

| ファイル | ベース | 内容 |
|---|---|---|
| `CLAUDE.md` | ctxmv | Commands / Architecture / Code Style / Testing / Gotchas の節構成。実ファイル |
| `AGENTS.md` | ctxmv | **`CLAUDE.md` へのシンボリックリンク**（`.agents/` ディレクトリは作らない） |
| `docsync.yml` | ctxmv | `README.md` ⇔ CLI Commandsソース、`DESIGN.md` ⇔ Config/Planningソースを紐付け |
| `README.md` | ctxmv | Usage / Configuration / Installation |
| `.github/workflows/test.yml` | ctxmv | swiftlint→unit testの依存付き、pathsフィルタ |
| `.github/workflows/docsync-check.yml` | ctxmv | そのまま流用可 |
| `.github/workflows/gitleaks.yml` | ctxmv | そのまま流用可 |
| `.github/workflows/update-nestfile.yml` | ctxmv | そのまま流用可 |
| `.github/workflows/publish-release.yml` | ctxmv | preflight→build(sedでVersion.swift書換→universal binary→tar.gz+sha256+artifactbundle)→commit-version→create-release の4段。**version-manager自身のbumpにversion-managerを使う（dogfooding）** |
| `Sources/VersionManagerCLI/Version.swift` | ctxmv | `enum VersionManagerVersion { static let current = "0.1.0" }` |
| `.appversion.yml`（リポジトリ自身のもの） | 新規 | commit-versionステップが書き換える対象を1本化。`files` に `Version.swift` /
`.claude/plugins/version-manager/.claude-plugin/plugin.json` / `plugins/version-manager/.codex-plugin/plugin.json` /
`.claude-plugin/marketplace.json`（`metadata.version`）/ `apm.yml`（`version`）を列挙し、
`publish-release.yml` の commit-version ステップは `sed` 個別書換ではなく
`version-manager bump "$VERSION"` を1回呼ぶだけにする（Eggのrelease.ymlは複数ファイルを
`sed` で個別に書き換えているが、version-managerはそれを自ツールで代替する最有力の
dogfooding先になる） |

### 5.3 移植しない（Egg固有・スコープ外）

- `.agents/`（ctxmv型シンボリックリンクを採用するため不要。§5.4のskillリポジトリ構造は
  Egg同様 `skills/` をSSoTとし、`.agents/` は経由しない）
- `Sources/*MCP/`、swift-sdk依存、`.mcp.json`（MCP統合なし。plugin.json自体は配るが
  `mcpServers` フィールドは持たない）
- `E2ETestsPackage/`（MVPではKitテストで足りる。必要になったら追加）
- `.github/workflows/docs.yml`, swift-docc-plugin, `*.docc/`（DocC公開なし）
- `.githooks/pre-push` と `.swift-ast-lint.yml` / my-swift-linter（Egg限定運用。
  導入する場合は後追いでnestfileに追加）
- ctxmvのLinuxクロスビルドジョブ（macOS向けMVPでは省略。`platforms: .macOS(.v15)` にして
  Foundation依存を最小に保ち、将来の追加余地は残す）

### 5.4 `install-skills` コマンド設計

Eggの5配布経路（plugin marketplace / Codex plugin / APM / `gh skill` / `npx skills`、
いずれも「外部ツールがリポジトリ構造を読みに来る」受動配布）に加えて、
version-manager自身が**能動的にskillファイルをターゲットプロジェクトへ書き込む**
`install-skills` サブコマンドを持つ。両者は独立に共存する（§5.1参照）。

```
version-manager install-skills [--agent claude-code|codex|both] [--dir <path>] [--force] [--json]
```

| オプション | 既定値 | 説明 |
|---|---|---|
| `--agent` | `both` | 書き込み先レイアウトの選択。詳細は下表 |
| `--dir` | カレントディレクトリ | インストール先プロジェクトのルート |
| `--force` | false | 既存の同名skillディレクトリを上書き |
| `--json` | false | 結果を `{"installed": [...], "skipped": [...]}` で出力 |

書き込み先（Eggの `.apm/skills/` シンボリックリンク方式ではなく、curl\|bash配布された
バイナリはリポジトリ内シンボリックリンクを作れないため**実体コピー**で書く）:

| `--agent` | 書き込み先 |
|---|---|
| `claude-code` | `<dir>/.claude/skills/<skill-name>/SKILL.md`（+ `references/`） |
| `codex` | `<dir>/.agents/skills/<skill-name>/SKILL.md`（+ `references/`）— DriveTrackerが
  実際にこのレイアウトへ移行済み（`.agents/skills` をSSoT化したリモートコミット実績あり）なので、
  Codex向けの既定パスとしてこれを採用する |
| `both`（既定） | 両方に書く |

**skill本文をバイナリにどう内包するか（設計上の要点）**: version-managerはcurl\|bashで
配布される単一実行バイナリであり、SwiftPMの `resources:` + `Bundle.module` は
「`.bundle` がバイナリと同じ相対位置に存在する」ことを前提とするため、
tarball展開後にバイナリだけ`$HOME/.local/bin`へ移す install.sh のフロー（Egg/ctxmv踏襲、
§5.1）とは相性が悪い。よって**ビルド時codegen**方式を採る:

- `skills/<name>/SKILL.md`（+`references/*.md`）をSSoT（Egg同様、リポジトリ直下 `skills/`）
- ビルド前スクリプト（`make generate-skills`、Makefileターゲット追加）が
  `skills/` を走査し `Sources/VersionManagerKit/Generated/GeneratedSkills.swift`
  （`package enum GeneratedSkills { package static let all: [SkillAsset] = [...] }`、
  各SKILL.mdの中身を文字列リテラルとして埋め込み）を生成する
- 生成物は `.gitignore` 対象（DriveTrackerの `GeneratedAnalytics.swift` と同じ運用パターン）。
  CIの `test.yml` は実行前に `make generate-skills` を挟む
- `SkillInstaller`（Kit層）は `GeneratedSkills.all` を読み、`--agent` に応じた
  パスへ `FileManagerProtocol` 経由で書き込む。既存ファイルとの差分比較は行わず、
  存在チェックのみ（`--force` なしで既存なら該当skillをスキップし `--json` の
  `skipped` に理由付きで載せる）

**配布するskillの内容（MVP最小構成）**: 最低1本、`.appversion.yml` の書き方ガイド
（`version-manager-config-guide` のようなSKILL.md、スキーマの要点とサンプルを
Concise にまとめたもの。§2のスキーマ説明をSKILL.md向けに再構成する）。
`egg-cli-guide` 相当の「CLI使用ガイド」も同時に用意し、`bump`/`check`のagent向け
使い方（`--json` 契約、非TTY安全性）を明記する。2本構成をMVPとする。

**apm.yml / plugin.json との関係**: `apm.yml` の `includes:` と `.claude/plugins/
version-manager/skills/` はEgg同様 `skills/` への参照（コピーまたはシンボリックリンク、
リポジトリ内なのでシンボリックリンクで問題ない）。`install-skills` が生成物から
書き込む対象（他プロジェクトの `.claude/skills/` 等）とは別軸——前者は
「version-managerリポジトリ自身をplugin化して配る」経路、後者は「version-manager
バイナリが能動的に配る」経路であり、SSoTである `skills/*/SKILL.md` を両方が参照する。

---

## 6. 命名規則

Eggの `*Runner.swift` / `*ArgumentsValidator.swift` / `ConfigValidator+*.swift` を踏襲する。

| パターン | 役割 | version-managerでの具体例 |
|---|---|---|
| `<Sub>Command.swift` | ArgumentParser定義（CLI層、コマンド毎に1ファイル） | `BumpCommand.swift`, `CheckCommand.swift`, `CurrentCommand.swift`, `InitCommand.swift`, `InstallSkillsCommand.swift`, `VersionManagerCommand.swift`（ルート） |
| `<Sub>Runner.swift` | コマンド実行ロジック（Kit層） | `BumpRunner.swift`, `CheckRunner.swift`, `CurrentRunner.swift`, `InitRunner.swift`, `InstallSkillsRunner.swift` |
| `<Sub>ArgumentsValidator.swift` | 実行前のCLI入力検証 | `BumpArgumentsValidator.swift`（新バージョン形式・フラグ組合せ検証） |
| `ConfigValidator+<Section>.swift` | configの部分バリデータ | `ConfigValidator+FilesValidator.swift`, `+RenamesValidator.swift`, `+HooksValidator.swift`, `+VersionFormatValidator.swift` |
| `<Noun>Plan.swift` / `<Noun>Planner.swift` | 計画の値型 / 計画構築 | `BumpPlan.swift`, `BumpPlanner.swift` |
| `<Noun>Applier.swift` | 計画の適用 | `PlanApplier.swift` |
| `<Noun>Renderer.swift` / `<Noun>Formatter.swift` | 出力整形 | `DiffRenderer.swift`, `ConfigDecodingErrorFormatter.swift` |
| `Regexes.swift`（Internals/） | 内部正規表現の一元定義 | `{version}` プレースホルダ検出、semverフォールバックパターン等。**正規表現リテラルの分散定義禁止**（ctxmvの「文字列リテラル直書き禁止・共通ユーティリティ集約」ルール準拠） |

その他のスタイル規約（CLAUDE.mdに明記する）:

- 1ファイル1型基準。ただし強く関連する型は親structにネスト（Eggの `Config` 方式）
- 文字列識別子はenum rawValue経由（環境変数名 `APPVERSION_*` も
  `enum HookEnvironmentKey: String` に集約）
- エラーは機能単位の `enum XxxError: Error, LocalizedError`、全ケースにcontextを持たせる
- 非自明な型・関数にはdoc comment、自明なコードにはコメントしない（ctxmv規約）

---

## 7. テスト戦略

**swift-testing**（`@Test` / `#expect` / `@testable import VersionManagerKit`、テスト型はstruct）。
Egg/ctxmv共通のパラメタライズドテストパターン
（`@Test("説明", arguments: XxxTestCase.allCases)` + `CustomTestStringConvertible` 準拠のケース列挙）を標準とする。

### 7.1 I/Oモック化

- ファイルI/O: `FileManagerProtocol`（Egg方式）でKit全体を抽象化。テストでは
  インメモリ実装を注入。fixtureベースのテスト（実YAML・実pbxproj断片）は
  `Tests/VersionManagerKitTests/Fixtures/` に置き `exclude` 指定（Egg方式）。
- プロセス実行: `ProcessRunning` のモックで hook の実行コマンド・環境変数・
  終了コード分岐を検証（実シェルを起動しない）。
- glob展開はモックFS上で行えるよう `FileSystemAccess`（Internals/）に薄くラップする。

### 7.2 領域別テストケース設計

**ConfigLoader / ConfigValidator**（Eggの `Fixtures/ConfigDecodingTests/*.yml` 方式）:
- 正常系: 最小構成 / フル構成 / `occurrences` の "all"・整数の多相デコード
- 異常系: 不正YAML / 必須キー欠落 / 不正regex / キャプチャグループ0個・2個 /
  ルートID重複 / パス脱出（`../`・絶対パス）/ `{version}` 欠落 /
  `source_of_truth` 参照不整合 → **各エラーのcontext（ruleID）がメッセージに含まれることまで検証**

**正規表現マッチ・置換（BumpPlanner）**:
- 単一マッチ / 同一行複数マッチ / 複数行マッチ（pbxproj風に同パターンがN回出現）
- **逆順置換の正しさ**: 置換後文字列長が変わるケース（`1.9.0`→`1.10.0` で桁増）で
  全マッチ箇所が正しく置換されること
- キャプチャグループ外（前後コンテキスト）が変更されないこと
- マルチバイト文字を含むファイルでのRange安全性
- glob: 複数ファイルマッチ / 0ファイルマッチ（エラー）

**SemanticVersion（独自実装のパース・比較）**:
- パース正常系: `"1.18.0"` / `"1.18.0-beta.1"` / `"1.18.0+build.5"` /
  `"1.18.0-beta.1+build.5"` / pre-release識別子の数値・英数字混在（`"1.0.0-x.7.z.92"`）
- パース異常系: `"1.18"`（不足） / `"v1.18.0"`（接頭辞） / `"01.2.3"`（先行ゼロ） /
  空文字列 / 空の識別子（`"1.0.0-"`）
- 比較（`Comparable`）: SemVer仕様書 §11 の公式precedence例
  （`1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 <
  1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0`）をそのままテストケース化
- buildMetadataは比較に一切影響しないこと（`"1.0.0+a" == "1.0.0+b"` と同順位）

**フォーマット検証（VersionFormatValidator）**:
- パラメタライズド: `format: semver` かつ `strict: true` で `"1.18.0-beta.1"` が拒否されること /
  `strict: false` で許容されること / `format: pattern` のカスタム完全一致

**PlanValidator**:
- 0マッチエラー / `occurrences` 不一致 / ルール間の旧バージョン不整合 /
  新旧同一エラー / リネーム先既存エラー

**VersionTransformer / リネーム**:
- `transform.run` 実行（モックProcessRunningでstdout1行を変換結果として受け取ること）/
  transform省略時の素通し / `format` テンプレ適用 /
  transform script異常系（非0終了・空stdout・複数行stdout → いずれもエラー）/
  旧バージョン名ファイルが存在しない場合のエラー

**PlanApplier**:
- モックFSで書き込み内容検証 / 途中I/O失敗時のロールバック（適用済みが原状復帰されること）/
  リネームが置換の後であること

**Runner統合（モックFS上のミニプロジェクト）**:
- `bump` エンドツーエンド（fixture一式→期待ファイル一式の比較）/ `--dry-run` が一切書き込まないこと /
  `check` の整合・不整合判定 / `current` の抽出 / `--json` 出力のデコード可能性

### 7.3 CI

`test.yml`（ctxmv流用）: swiftlint job → test job の依存付き。`paths` フィルタで
`Sources/**`, `Tests/**`, `Package.swift`, `.swiftlint.yml` 変更時のみ発火。

---

## 8. 段階的実装ロードマップ

コミット粒度は `.gitnagg.yml`（200行/6ファイルでerror）に従い小さく刻む。

### Phase 0: リポジトリ骨組み（ハーネス移植）
1. `swift package init` 相当の3層Package.swift + 空のコマンド4つ（`--help` が出るだけ）
2. §5.1のハーネス一式コピー（Makefile / nestfile / lint / hooks / .claude / .codex / .githooks）
3. CLAUDE.md 作成 + AGENTS.md symlink、`make check` が通る状態に
4. `.github/workflows/` の test / gitleaks / docsync-check / update-nestfile

### Phase 1: MVP — `bump` と `check` の置換のみ
1. `Config` + `ConfigLoader`（Yams）+ `ConfigDecodingErrorFormatter`
2. `ConfigValidator`（files セクションのみ: regex検証・グループ数・パス脱出・ID重複）
3. `SemanticVersion`（独自SemVer 2.0.0実装、パース・`Comparable`）+ `VersionFormatValidator`（semverのみ）
4. `BumpPlanner`（glob展開・逆順置換）+ `BumpPlan` + `PlanValidator`（0マッチ・occurrences・新旧同一）
5. `PlanApplier`（アトミック書き込み・ロールバック）+ `DiffRenderer`
6. `BumpCommand`/`BumpRunner`（`--dry-run` 込み）、`CheckCommand`/`CheckRunner`
7. ここまでのユニットテスト一式

**MVP完了条件**: DriveTrackerに `files` のみの `.appversion.yml` を置き、
`version-manager bump --dry-run 1.18.0` で正しいdiffが出て、本実行で置換できること。

### Phase 2: リネームとフック
1. `RenameRule` + `VersionTransformer` + PlanValidator/PlanApplierへのリネーム統合
2. `Hooks` + `HookRunner`（ProcessRunning、`APPVERSION_*` 環境変数、pre/post、`--skip-hooks`）
3. `CurrentCommand`/`CurrentRunner` + `source_of_truth`
4. checkへのバージョン整合検証（ルール間不一致検知）追加

### Phase 3: UX・エコシステム
1. `--json` 全コマンド対応（構造化出力）
2. `InitCommand`（雛形生成）
3. `format: pattern`（カスタムバージョン形式。build number運用対応）
4. README / docsync.yml 整備
5. skill本文執筆（`version-manager-config-guide` / `version-manager-cli-guide` の2本、§5.4）
6. `make generate-skills` codegen（`skills/*/SKILL.md` → `GeneratedSkills.swift`）
7. `InstallSkillsCommand`/`InstallSkillsRunner`/`SkillInstaller`（`--agent`分岐・`--force`・`--json`）
8. §5.4の配布物一式（`.claude-plugin/marketplace.json`, `.claude/plugins/version-manager/`,
   `plugins/version-manager/.codex-plugin/`, `apm.yml`）を配置

### Phase 4: リリース基盤
1. `Version.swift` + `publish-release.yml`（ctxmv版4段構成の移植）
2. `install.sh`（Egg版チェックサム検証あり）
3. リポジトリ自身の `.appversion.yml` を作成（`Version.swift` に加え、Phase 3で配置した
   plugin.json×2・marketplace.json・apm.ymlの `version` フィールドを `files` に列挙）。
   `publish-release.yml` の commit-version ステップを `sed` 個別書換から
   `version-manager bump "$VERSION"` 呼び出しへ置き換える
4. v0.1.0リリース → **以後のバージョン管理をversion-manager自身の `.appversion.yml` で行う（dogfooding）**

### 将来候補（設計上の拡張余地のみ確保、実装しない）
- Linuxクロスビルド（ctxmv前例あり）
- `bump --major/--minor/--patch`（currentからの自動インクリメント。独自`SemanticVersion: Comparable`で対応可能）
- CHANGELOGエントリ自動挿入の組み込み（当面はpost hookで代替）
