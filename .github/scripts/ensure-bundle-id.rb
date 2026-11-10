#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Developer Portal に Bundle ID（App ID）を登録し、entitlements が求める capability を有効にする。
# 2 回目以降は確認だけで何もしない。
#
# Bundle ID は Export（-allowProvisioningUpdates）でも自動で登録されるが、iCloud を使うアプリは、
# App ID に iCloud のコンテナを割り当てるまで、Export の後の entitlement の確認で止まる。
# コンテナの割り当ては Web 画面でしかできず、割り当てるには App ID が先に要るので、archive の前に API で登録しておく。
# 登録すると、App Store Connect の「新規 App」のバンドル ID の候補にも出る。
#
# 有効にする capability（entitlements のキーから決める）:
#   com.apple.developer.icloud-services → ICLOUD（CloudKit を含む。ICLOUD_VERSION = XCODE_6）
# iCloud のコンテナの作成と App ID への割り当ては API で行えないため、capability を有効にしたときに手順を Job Summary に出す。
#
# 使い方（環境変数で渡す）:
#   BUNDLE_ID=jp.shilokuma.MyApp APP_NAME="My App" ENTITLEMENTS=MyApp/MyApp.entitlements \
#   API_KEY_PATH=AuthKey_XXXXXXXXXX.p8 APPLE_API_KEY_ID=XXXXXXXXXX APPLE_API_ISSUER_ID=xxxxxxxx-... \
#   ruby .github/scripts/ensure-bundle-id.rb
#
# Ruby の標準ライブラリだけで動く（gem のインストールは不要）。API の共通処理は app_store_connect.rb にある。

require_relative 'app_store_connect'

# entitlements のキー → 有効にする capability と設定
CAPABILITIES = {
  'com.apple.developer.icloud-services' => {
    type: 'ICLOUD',
    name: 'iCloud（CloudKit）',
    settings: [{ key: 'ICLOUD_VERSION', options: [{ key: 'XCODE_6' }] }]
  }
}.freeze

def find_bundle_id(identifier, token)
  json = AppStoreConnect.request(
    :get, '/v1/bundleIds',
    token: token,
    query: { 'filter[identifier]' => identifier, 'fields[bundleIds]' => 'identifier,name,platform', 'limit' => '200' }
  )
  # filter は前方一致でも返るので、identifier が一致するものだけを見る
  json.fetch('data').find { |bundle| bundle.dig('attributes', 'identifier') == identifier }
end

# 1 つの App ID を iOS・macOS・visionOS で使うので UNIVERSAL で登録する。受け付けられなければ IOS で登録し直す
def register_bundle_id(identifier, name, token)
  %w[UNIVERSAL IOS].each do |platform|
    body = { data: { type: 'bundleIds', attributes: { identifier: identifier, name: name, platform: platform } } }
    begin
      return AppStoreConnect.request(:post, '/v1/bundleIds', token: token, body: body).fetch('data')
    rescue AppStoreConnect::Error => e
      raise unless platform == 'UNIVERSAL' && e.status.to_s == '409'

      puts "::notice::platform UNIVERSAL では登録できなかったため、IOS で登録し直します（HTTP #{e.status}）"
    end
  end
end

def enabled_capabilities(bundle_id_id, token)
  json = AppStoreConnect.request(:get, "/v1/bundleIds/#{bundle_id_id}/bundleIdCapabilities", token: token)
  json.fetch('data').map { |capability| capability.dig('attributes', 'capabilityType') }
end

def enable_capability(bundle_id_id, capability, token)
  body = {
    data: {
      type: 'bundleIdCapabilities',
      attributes: { capabilityType: capability.fetch(:type), settings: capability.fetch(:settings) },
      relationships: { bundleId: { data: { type: 'bundleIds', id: bundle_id_id } } }
    }
  }
  AppStoreConnect.request(:post, '/v1/bundleIdCapabilities', token: token, body: body)
end

def icloud_guide(bundle_id)
  <<~MARKDOWN
    ## iCloud のコンテナを App ID に割り当ててください

    App ID `#{bundle_id}` の iCloud（CloudKit）を有効にしました。コンテナの作成と割り当ては API で行えないため、Apple Developer の Certificates, Identifiers & Profiles で行います。

    1. Identifiers →「＋」→ iCloud Containers で `iCloud.#{bundle_id}` を作る（作成済みなら不要）
    2. Identifiers で App ID `#{bundle_id}` を開き、iCloud の「Edit」で上のコンテナにチェックを付けて保存する

    割り当てるまで、Export の後の entitlement の確認（Check entitlements）で止まります。
  MARKDOWN
end

bundle_id = AppStoreConnect.env!('BUNDLE_ID')
# Bundle ID の名前に使えるのは英数字と空白だけ
app_name = AppStoreConnect.env!('APP_NAME').gsub(/[^A-Za-z0-9 ]/, ' ').squeeze(' ').strip
entitlements_path = AppStoreConnect.env!('ENTITLEMENTS')
abort "::error::entitlements が見つかりません: #{entitlements_path}" unless File.exist?(entitlements_path)

entitlements = File.read(entitlements_path)
required = CAPABILITIES.select { |key, _| entitlements.include?("<key>#{key}</key>") }.values
token = AppStoreConnect.token_from_env

begin
  bundle = find_bundle_id(bundle_id, token)
  if bundle
    puts "Bundle ID は登録済みです: #{bundle_id}（#{bundle.dig('attributes', 'name')}、#{bundle.dig('attributes', 'platform')}）"
  else
    bundle = register_bundle_id(bundle_id, app_name.empty? ? bundle_id.tr('.', ' ') : app_name, token)
    message = "Bundle ID を登録しました: #{bundle_id}（#{bundle.dig('attributes', 'name')}、#{bundle.dig('attributes', 'platform')}）"
    puts "::notice::#{message}"
    AppStoreConnect.write_summary("## Bundle ID を登録しました\n\n#{message}")
  end

  enabled = enabled_capabilities(bundle.fetch('id'), token)
  required.each do |capability|
    if enabled.include?(capability.fetch(:type))
      puts "#{capability.fetch(:name)} は有効です"
      next
    end

    enable_capability(bundle.fetch('id'), capability, token)
    puts "::notice::App ID #{bundle_id} の #{capability.fetch(:name)} を有効にしました"
    AppStoreConnect.write_summary(icloud_guide(bundle_id)) if capability.fetch(:type) == 'ICLOUD'
  end
rescue AppStoreConnect::Error => e
  abort "::error::#{e.message}"
end
