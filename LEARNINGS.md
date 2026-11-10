# LEARNINGS — idfa-vault-ios の知見

このリポジトリだけで通じる知見を溜める（全リポジトリ共通の知見は `~/.agents/LEARNINGS.md`）。

- 1 項目 = 1 つの箇条書き。見出しの下に追記し、日付（YYYY-MM-DD）を添える
- コードや git の履歴を読めば分かることは書かない。PC 固有の値（ローカルパス・Simulator の UDID）と秘密情報は書かない
- 古くなった項目は消すか直す

## ビルド・テスト

- Xcode 26.6 では、iOS Simulator のビルドは iCloud の entitlement を付けたまま「Sign to Run Locally」で通り、Unit テストも流れる（profile は要らない）。macOS はアドホック署名に iCloud の entitlement を付けると起動できないため、アドホック署名（`IDFAVAULT_ADHOC_SIGNING=YES`）のときは付けない（2026-11-10）
- GitHub Actions の `macos-26` のイメージには Xcode 26.6 用の visionOS のランタイムが入っていて、`generic/platform=visionOS Simulator` のビルドにダウンロードは要らない（2026-11-10）

## 配布

- 署名せずに作った archive を Export すると、archive の署名に無い entitlement（iCloud）は profile にあっても付かない。`Tools/embed_archive_entitlements.py` で archive の .app にアドホック署名で埋め込んでから Export する（ask-hub-apple の push と同じ。2026-11-10）
