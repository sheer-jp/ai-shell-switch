# AI Shell Switch

MacBookの蓋を閉じている間もローカルAI処理を継続させるための、メニューバー常駐スイッチです。

> [!CAUTION]
> ONはmacOSのスリープを無効化します。必ず電源アダプタを接続し、Macをバッグや布の中に入れず、作業後はOFFへ戻してください。

## 必要環境

- macOS 13以降
- Xcode Command Line Tools（`swiftc`）
- 電源アダプタ（ON時）

## クイックスタート

```sh
git clone https://github.com/sheer-jp/ai-shell-switch.git
cd ai-shell-switch
./install.sh
```

インストール後、画面上部に表示される `AI OFF` をクリックして切り替えます。初回のON操作ではmacOSの管理者確認が表示されます。

## 使い方

1. `dist/AI Shell Switch.app` を起動します。
2. 画面上部の `AI OFF` をクリックします。
3. `AI稼働モードにする（ON）` を選び、macOSの管理者確認を許可します。
4. 作業後は `通常スリープに戻す（OFF）` を選びます。

表示の意味:

- `AI ON`: 蓋を閉じてもスリープしない設定です。
- `AI OFF`: 普通のmacOSスリープ設定です。
- `AI ON ⚠︎`: ONのままバッテリー駆動になっています。電源を接続するかOFFにしてください。

ONは電源アダプタ接続中だけ許可します。Macを布やバッグに入れず、通気を確保してください。

## ログイン時にも表示する

初回起動時にユーザー用のログイン起動へ自動登録します。メニューバーの `AI OFF` / `AI ON` をクリックし、`ログイン時にも起動` のチェックからいつでも登録・解除できます。

## ビルドとインストール

```sh
./build.sh
./install.sh
```

`build.sh` は `dist/AI Shell Switch.app` を生成します。`install.sh` は `~/Applications` にコピーして起動します。

## ターミナル版

短いコマンドを設定済みのMacでは、次の形でも利用できます。

```sh
ai-on
ai-status
ai-off
```

別のMacでは、リポジトリ内のスクリプトを直接利用できます。

```sh
./ai-shell-switch.sh on
./ai-shell-switch.sh status
./ai-shell-switch.sh off
```

このスイッチはAIタスク自体を起動・停止するものではありません。Codex、Claude、tmuxなどで開始済みの処理が、Macのスリープで止まらないようにするものです。

## テスト

```sh
./test.sh
```

非破壊テストではシェルとSwiftの構文、状態表示契約、Info.plistを確認します。実機テストでは最後に必ずOFFへ戻します。

## 技術的な境界

- `pmset disablesleep` の実際の挙動はMacの機種、macOS、電源、外部ディスプレイ、温度条件に左右されます。
- このアプリはAIタスクやネットワーク接続を監視・再開しません。
- OFF時は `SleepDisabled=0` に戻し、通常のmacOSスリープ動作を使います。

## License

[MIT License](LICENSE)
