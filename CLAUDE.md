# CLAUDE.md

このファイルは、このリポジトリで作業する Claude Code（ほかの AI エージェントを含む）への指示です。

## プロジェクト

自分の端末の IDFA（広告識別子）を、生体認証のうしろで確認・コピーするアプリ **IDFA Vault**（Bundle ID `jp.shilokuma.IDFAVault`）。
同じ Apple ID の他の端末の IDFA も、CloudKit の非公開データベースで同期して一覧に出す。
自分の IDFA を取れるのは iPhone・iPad だけ（macOS・visionOS は IDFA を渡さない。LEARNINGS.md）。Mac と visionOS は、同じ iCloud の iPhone・iPad の IDFA を見るだけにし、その OS では取得できないことを画面に出す。トラッキングの許可を求めず、自分のレコードも書かない（2026-11-10 にユーザーが決定）。
仕様書（IDFA_Vault_SPEC.md）とデザインの原本（design-reference の HTML）はユーザーから渡されたもので、リポジトリには入れていない。食い違えば仕様書が優先する。

方針（仕様書の「競合との違い」。実装で必ず守る）:

1. **起動時に必ず生体認証を求める**: Face ID / Touch ID / Optic ID、無ければパスコード（Mac はパスワード）。バックグラウンドから戻ったときも、設定の自動ロックの時間を過ぎていればロックする。アプリスイッチャーのスナップショットに IDFA を映さない
2. **同期は iCloud の非公開データベースだけ**: パブリック DB・シェア DB・サーバーは使わない。開発者に IDFA が届く経路を作らない
3. **広告・外部 SDK を入れない**: SPM のパッケージは SwiftLint のプラグインだけ。ほかのパッケージは足さない
4. **端末ごとに専用のレイアウト**: iPhone・iPad・Mac・visionOS で、iPhone の画面を引き伸ばさない

デザイン（ヒートティント）の決まり:

- **角丸を使わない**。カード・ボタン・アイコン台・バッジは面取りの八角形（`ChamferedRect`）か、左右を尖らせた六角形で作る。例外はアプリアイコンの外形・macOS のウインドウ枠・信号ボタンなど OS 標準の部分
- 常にダーク表示（ライトモードでも同じ配色）
- 生体認証のマークは SF Symbols の公式シンボル（`faceid`・`touchid`・`opticid`・`lock`）を使い、独自に描かない
- iPhone SE（375×667）でレイアウトが崩れないこと

## 環境

- Xcode 26.6 / iOS・iPadOS 17.0 以上・macOS 14.0 以上・visionOS 1.0 以上（新しい API は `if #available` で囲む）
- SwiftUI のマルチプラットフォームの 1 ターゲット（`SDKROOT = auto`・`TARGETED_DEVICE_FAMILY = "1,2,7"`）。iPhone は縦だけ
- Swift 6（言語モード 6・Strict Concurrency complete・既定の分離は MainActor。UI テストのターゲットだけ nonisolated）
- SwiftUI・`@Observable` / Swift Testing（Unit）/ XCTest（UI テスト）/ SwiftLint 0.65.1（Build Tool Plugin と CI の `--strict`）
- 開発言語は `en`。文字列は String Catalog（`Localizable.xcstrings`）で、英語をキーにして主要言語の訳を入れる

## ビルド・テスト

```bash
export DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer   # xcode-select が別の Xcode のとき
# iOS Simulator（名前ではなく UDID で指定する。xcrun simctl list devices available）
xcodebuild test -project IDFAVault.xcodeproj -scheme IDFAVault \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath <リポジトリの外> \
  -skipPackagePluginValidation -skipMacroValidation -parallel-testing-enabled NO
# Unit テストだけ: -only-testing:IDFAVaultTests を足す
# macOS（CI と同じアドホック署名。iCloud の entitlement は付かない）
xcodebuild test -project IDFAVault.xcodeproj -scheme IDFAVault -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath <リポジトリの外> -skipPackagePluginValidation -skipMacroValidation \
  -skip-testing:IDFAVaultUITests -parallel-testing-enabled NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
  IDFAVAULT_ADHOC_SIGNING=YES ENABLE_APP_SANDBOX=NO
# visionOS（ビルドだけ）
xcodebuild build -project IDFAVault.xcodeproj -scheme IDFAVault -destination 'generic/platform=visionOS Simulator' \
  -derivedDataPath <リポジトリの外> -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO
# SwiftLint（CI と同じ。SPM が解決したバイナリを使う）
"$(find <DerivedData>/SourcePackages/artifacts -type f -name swiftlint -path '*macos*' | head -1)" lint --strict
```

- テストのホストのアプリは、CloudKit・LocalAuthentication・AdSupport を直接呼ばない形で起動させる（CI の macOS は iCloud の entitlement が無く、`CKContainer` を作ると落ちる）。外のサービスはプロトコルの向こうに置き、テストでは偽物を渡す

## ブランチ運用

- ベースブランチは `develop`。作業ブランチは `feat/issue-<番号>-<内容>` などで切り、PR は `develop` 宛てにする
- コミットは `[type] メッセージ`（日本語）、PR のタイトルは `【TYPE】タイトル`。マージは merge commit（Squash しない）
- リポジトリだけの知見は [LEARNINGS.md](LEARNINGS.md) に書く
