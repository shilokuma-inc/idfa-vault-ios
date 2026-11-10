# LEARNINGS — idfa-vault-ios の知見

このリポジトリだけで通じる知見を溜める（全リポジトリ共通の知見は `~/.agents/LEARNINGS.md`）。

- 1 項目 = 1 つの箇条書き。見出しの下に追記し、日付（YYYY-MM-DD）を添える
- コードや git の履歴を読めば分かることは書かない。PC 固有の値（ローカルパス・Simulator の UDID）と秘密情報は書かない
- 古くなった項目は消すか直す

## ビルド・テスト

- Xcode 26.6 では、iOS Simulator のビルドは iCloud の entitlement を付けたまま「Sign to Run Locally」で通り、Unit テストも流れる（profile は要らない）。macOS はアドホック署名に iCloud の entitlement を付けると起動できないため、アドホック署名（`IDFAVAULT_ADHOC_SIGNING=YES`）のときは付けない（2026-11-10）
- xcodebuild のビルドでは、`Localizable.xcstrings` に新しいキーが書き足されない（Xcode の画面でビルドしたときだけ同期される）。抽出したキーは DerivedData の `*.stringsdata`（JSON）に出るので、新しい文字を足したらそこと見比べてカタログに英語のキーと訳を足す（2026-11-10）
- `switch` で `LocalizedStringResource?` を返すプロパティの文字列は、`*.stringsdata` に抽出されないことがある（実行時には訳が引ける）。カタログには手で足す（2026-11-10）
- GitHub Actions の `macos-26` のイメージには Xcode 26.6 用の visionOS のランタイムが入っていて、`generic/platform=visionOS Simulator` のビルドにダウンロードは要らない（2026-11-10）

## 配布

- 署名せずに作った archive を Export すると、archive の署名に無い entitlement（iCloud）は profile にあっても付かない。`Tools/embed_archive_entitlements.py` で archive の .app にアドホック署名で埋め込んでから Export する（ask-hub-apple の push と同じ。2026-11-10）
- App ID の iCloud を有効にしただけで、コンテナを割り当てていないと、API Key の Export（`-allowProvisioningUpdates`）が `exportArchive Authentication failed` → `No profiles for '<Bundle ID>' were found` で止まる（entitlement の確認より手前）。コンテナの作成と割り当ては API に無いので Web で行う。割り当てた後は同じ鍵で iOS・macOS・visionOS とも通った（2026-11-10）
- ASC API の Bundle ID は `platform: UNIVERSAL` で登録でき、その App ID で iOS（IPA）・macOS（pkg）・visionOS（IPA）の Export とアップロードが通った（2026-11-10）
- 作ったばかりのアプリでは、`/v1/apps/<id>/appPriceSchedule` は未設定でもアプリと同じ ID を返し、その `manualPrices` が 404 になる。配信状況（`appAvailabilityV2` → `territoryAvailabilities`）も 404 は未設定として扱う（2026-11-10）
- 版に言語（`appStoreVersionLocalizations`）を足すと、App 情報の同じ言語（`appInfoLocalizations`）も App Store Connect が作る。続けて App 情報の言語を POST すると `409 ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE` になる（2026-11-10）

## ローカライズ

- iOS の設定の「App からのトラッキング要求を許可」の各言語の表記は、Simulator のランタイムの `System/Library/PrivateFrameworks/Settings/PrivacySettingsUI.framework/<言語>.lproj/Privacy.strings` の `ALLOW_ASK` にある。「プライバシーとセキュリティ」「トラッキング」は `System/Library/PreferenceBundles/PrivacyAndSecuritySettings.bundle` の `Localizable.strings`。iOS 26.5 の日本語は「アプリからのトラッキング要求を許可」（「App」ではない）（2026-11-10）
- 縦に `fixedSize` した `Text` でも、行の終わりがちょうど幅いっぱいになる文（iPhone SE のドイツ語の未許可の説明）で、高さが 1 行少なく見積もられて末尾が「…」になった。言語を足したら、iPhone SE で長い文の画面を全言語で撮って確かめ、切れたら文言を少し変える（2026-11-10）

## プラットフォーム

- visionOS の SDK には AdSupport（`ASIdentifierManager`）が無く、visionOS のネイティブのアプリは自分の IDFA を取得できない。実行環境には AdSupport.framework があるが、iPad の互換アプリ（Designed for iPad）用。AppTrackingTransparency は SDK にある（2026-11-10）
- `sensoryFeedback(_:trigger:)` は visionOS では 26.0 から（iOS 17・macOS 14 とずれる）（2026-11-10）
