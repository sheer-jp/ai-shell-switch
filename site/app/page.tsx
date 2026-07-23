import Image from "next/image";

const repositoryUrl = "https://github.com/sheer-jp/ai-shell-switch";
const sourceZipUrl =
  "https://github.com/sheer-jp/ai-shell-switch/archive/refs/heads/main.zip";

const commands = [
  ["ai-on", "スリープ禁止をON(AC電源接続中のみ)"],
  ["ai-off", "OFFにして、通常のmacOSスリープへ戻す"],
  ["ai-toggle", "ONとOFFを切り替える"],
  ["ai-status", "いまの状態と電源を表示する"],
  ["ai-doctor", "動作環境を診断する"],
];

export default function Home() {
  return (
    <div className="wrap">
      <header className="site-head">
        <a className="brand" href="#top">
          <Image src="/app-icon.png" alt="" width={28} height={28} priority />
          <span>AI Shell Switch</span>
        </a>
        <nav aria-label="外部リンク">
          <a href={repositoryUrl} target="_blank" rel="noreferrer">
            GitHub
          </a>
        </nav>
      </header>

      <main id="top">
        <section className="intro">
          <p className="labs-line">
            Trust Driven System Labs の実験的プロダクトです。v1.3 ·
            オープンソース(MIT)
          </p>
          <Image
            className="intro-icon"
            src="/app-icon.png"
            alt="AI Shell Switch のアプリアイコン"
            width={88}
            height={88}
            priority
          />
          <h1>
            ローカルAIを走らせているあいだ、
            <br />
            Macを眠らせないでおく。
          </h1>
          <p className="lead">
            AI Shell Switch は、macOSのスリープ設定を切り替えるだけの
            小さなユーティリティです。
            長時間のローカルAI処理やビルドの途中でMacがスリープして止まってしまう——
            それだけを防ぎます。 AIを起動したり、監視したりはしません。
            終わったらOFFにすれば、いつものスリープ動作に戻ります。
          </p>
          <div className="actions">
            <a className="button" href={repositoryUrl} target="_blank" rel="noreferrer">
              GitHubでソースを見る
            </a>
            <a className="textlink" href={sourceZipUrl}>
              ソースZIPをダウンロード ↓
            </a>
          </div>
          <p className="build-note">
            署名済みアプリの配布ではありません。ソースを取得して、自分のMac上でビルドして使います(
            <a href="#install">手順はこちら</a>
            )。macOS 13以降・Apple Silicon対応。アカウント登録は不要です。
          </p>
        </section>

        <hr />

        <section>
          <h2>何をするのか</h2>
          <p>
            扱うのは、macOSがもともと持っているスリープ設定(
            <code>SleepDisabled</code>
            )ひとつだけです。 ONにするとスリープを止め、OFFにすると元に戻す。
            それ以上のことはしません。
          </p>
          <ul className="plain">
            <li>
              Macアプリ・メニューバー・CLIのどこから操作しても、同じ設定値を読み書きします。UIとターミナルで状態が食い違いません。
            </li>
            <li>
              AIタスクの起動・監視・スケジューリングは行いません。ページ内の画面例もあくまで例です。
            </li>
            <li>
              データはMacの外に出ません。ネットワーク通信も計測もありません。
            </li>
          </ul>
        </section>

        <section>
          <h2>ターミナルからも同じことができます</h2>
          <p>
            コマンドは5つだけです。スクリプトやエージェントのワークフローにそのまま組み込めます。
          </p>
          <pre className="terminal">
            <code>
              <span className="prompt">$</span>
              {" ai-status\nAIクラムシェル運転: READY\n電源: AC Power\n"}
              <span className="prompt">$</span>
              {" ai-on"}
            </code>
          </pre>
          <dl className="commands">
            {commands.map(([name, description]) => (
              <div key={name}>
                <dt>
                  <code>{name}</code>
                </dt>
                <dd>{description}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section>
          <h2>安全側に倒してあります</h2>
          <p>
            スリープを止める機能は、使い方を誤ると発熱やバッテリー消費につながります。そのため最初から次のように決めています。
          </p>
          <ul className="plain">
            <li>
              <strong>ONにできるのはAC電源接続中だけ。</strong>
              バッテリー駆動中に新しくONにすることはできません。
            </li>
            <li>
              <strong>OFFはいつでも実行できます。</strong>
              ショートカット ⌃⌥A からも、すぐ通常スリープへ戻せます。
            </li>
            <li>
              <strong>
                管理者権限で触るのは <code>pmset</code> の
                SleepDisabled(0と1)だけ。
              </strong>
              それ以外のコマンドは許可していません。
            </li>
          </ul>
        </section>

        <hr />

        <section id="install">
          <h2>インストール</h2>
          <p>
            Xcode Command Line Tools を使って、自分のMacでビルドします。3ステップです。
          </p>
          <ol className="steps">
            <li>
              <p>開発ツールを入れる(すでにあればスキップ)</p>
              <pre>
                <code>xcode-select --install</code>
              </pre>
            </li>
            <li>
              <p>ソースを取得する</p>
              <pre>
                <code>git clone {repositoryUrl}.git</code>
              </pre>
            </li>
            <li>
              <p>ビルドして起動する</p>
              <pre>
                <code>{"cd ai-shell-switch\n./install.sh"}</code>
              </pre>
            </li>
          </ol>
          <p className="fine">
            ZIPでダウンロードした場合は <code>~/Downloads/ai-shell-switch-main</code>{" "}
            に移動して <code>./install.sh</code> を実行してください。
          </p>
          <p className="fine">
            現在は Developer ID
            による署名・Apple公証を行っていない、ソース配布の段階です。
            初回起動時にmacOSの確認が出ることがあります(
            <a
              href="https://support.apple.com/en-us/102445"
              target="_blank"
              rel="noreferrer"
            >
              Appleの解説
            </a>
            )。 ソースはすべて公開しているので、中身を確認してからビルドできます。
          </p>
        </section>

        <section>
          <h2>知っておいてほしいこと</h2>
          <ul className="plain">
            <li>ON中は電源アダプタにつなぎ、通気を確保してください。</li>
            <li>
              フタを閉じた状態(クラムシェル)での実際の動作は、機種・macOSのバージョン・電源・外部ディスプレイの有無などの条件で異なります。
            </li>
            <li>
              Labsの実験的プロダクトとして公開しています。完成品のアプリ配布ではありませんが、壊れたら直します。気づいたことは{" "}
              <a href={`${repositoryUrl}/issues`} target="_blank" rel="noreferrer">
                GitHubのIssue
              </a>{" "}
              へどうぞ。
            </li>
          </ul>
        </section>
      </main>

      <footer className="site-foot">
        <p>AI Shell Switch — Trust Driven System Labs</p>
        <p>
          <a href={repositoryUrl} target="_blank" rel="noreferrer">
            GitHub
          </a>{" "}
          ·{" "}
          <a href={`${repositoryUrl}/blob/main/LICENSE`} target="_blank" rel="noreferrer">
            MIT License
          </a>{" "}
          · <a href="#top">上へ戻る ↑</a>
        </p>
      </footer>
    </div>
  );
}
