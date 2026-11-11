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
- Apple 側の画像の取り込み（スクリーンショットの `assetDeliveryState`、Asset Library の画像の `state`）は、混む日は 1 枚で 20 分を超える。1 言語・1 枚ずつ待つと最初の 1 枚で上限に達して残りが上がらないので、全部を上げてからまとめて待ち、流し直したら上げ直さずに続きから待つ（スクリーンショットは `sourceFileChecksum`、クリエイティブは参照名に入れたハッシュで同じ画像か見分ける）（2026-11-10）
- Asset Library の画像の参照名（`referenceName`）はライブラリの中で一意。途中で失敗した実行の画像が残っていると、同じ参照名の POST が `409 ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE` になる（2026-11-10）
- ASC API は、期限内（作ってから 4 分）のトークンでも、まれに `401 NOT_AUTHORIZED` を返す。36 枚の取り込みの状態を 10 秒ごとに問い合わせているときに、PATCH と GET の両方で出た。トークンを作り直して 1 回だけ送り直し、待ちの問い合わせは 30 秒おきにする（2026-11-10）

## ローカライズ

- iOS の設定の「App からのトラッキング要求を許可」の各言語の表記は、Simulator のランタイムの `System/Library/PrivateFrameworks/Settings/PrivacySettingsUI.framework/<言語>.lproj/Privacy.strings` の `ALLOW_ASK` にある。「プライバシーとセキュリティ」「トラッキング」は `System/Library/PreferenceBundles/PrivacyAndSecuritySettings.bundle` の `Localizable.strings`。iOS 26.5 の日本語は「アプリからのトラッキング要求を許可」（「App」ではない）（2026-11-10）
- 縦に `fixedSize` した `Text` でも、行の終わりがちょうど幅いっぱいになる文（iPhone SE のドイツ語の未許可の説明）で、高さが 1 行少なく見積もられて末尾が「…」になった。言語を足したら、iPhone SE で長い文の画面を全言語で撮って確かめ、切れたら文言を少し変える（2026-11-10）

## プラットフォーム

- 自分の IDFA を取れるのは iPhone・iPad だけ。visionOS の SDK には AdSupport（`ASIdentifierManager`）が無い（実行環境の AdSupport.framework は iPad の互換アプリ用）。macOS は Apple の資料のとおり `ATTrackingManager.trackingAuthorizationStatus` が常に `notDetermined` で、`requestTrackingAuthorization` は前面でもダイアログを出さずに一瞬で `notDetermined` を返し、IDFA は 0。Mac の Designed for iPad（`isiOSAppOnMac`）でも同じで、Vision Pro で iPad アプリとして動かしても取れなかった（2026-11-10）
- `sensoryFeedback(_:trigger:)` は visionOS では 26.0 から（iOS 17・macOS 14 とずれる）（2026-11-10）
- `INFOPLIST_KEY_NSUserTrackingUsageDescription` を `[sdk=iphoneos*]` などの条件付きだけで書くと、条件に当てはまらない macOS・visionOS の `Info.plist` にはキーが空の値（""）で入る。macOS・visionOS のバイナリも AppTrackingTransparency をリンクしているので、配信のときに ITMS-90738（Invalid purpose string value）の警告メールが来た。許可を求めないプラットフォームでは、ATT をリンクせず、文言のキーも入れない。キーを入れないには、条件付きの `INFOPLIST_KEY_*` ではなく `INFOPLIST_FILE[sdk=iphoneos*]` で `Info.plist` を分ける（2026-11-11）
- visionOS の版が Guideline 2.1 でリジェクトされた。理由は「AppTrackingTransparency を使っているのに、許可のダイアログが見つからない」。visionOS では許可を求めない仕様で、審査メモにも理由を書いていた。それでも、ATT をリンクしていて、「App のプライバシー」（全プラットフォームで共通）でデバイス ID をトラッキングと申告していたので、ダイアログを探された。同じ版で、visionOS の実機のデモ動画も求められた。iPhone の動画の添付だけでは足りない（2026-11-11）
