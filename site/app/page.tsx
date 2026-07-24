import Image from "next/image";

const repositoryUrl = "https://github.com/sheer-jp/ai-shell-switch";
const sourceZipUrl =
  "https://github.com/sheer-jp/ai-shell-switch/archive/refs/heads/main.zip";

const commands = [
  ["ai-on", "スリープを止める(AC電源接続中のみ)"],
  ["ai-off", "いつものスリープに戻す"],
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
          <p className="lead">{"AI Shell Switch は、macOSのスリープ設定を切り替えるだけの小さなユーティリティです。長時間のローカルAI処理やビルドの途中でMacがスリープして止まってしまう——それだけを防ぎます。AIを起動したり、監視したりはしません。終わったらOFFにすれば、いつものスリープに戻ります。"}</p>
          <ul className="spec">
            <li>macOS 13以降</li>
            <li>Apple Silicon</li>
            <li>MIT License</li>
            <li>アカウント不要</li>
          </ul>
          <div className="actions">
            <a className="button" href={repositoryUrl} target="_blank" rel="noreferrer">
              GitHubでソースを見る
            </a>
            <a className="textlink" href={sourceZipUrl}>
              ソースZIPをダウンロード ↓
            </a>
          </div>
          <p className="build-note">
            {"署名済みアプリの配布ではありません。ソースを取得して、自分のMacでビルドして使います("}
            <a href="#install">手順はこちら</a>
            {")。macOS専用のツールで、Windowsでは動きません。"}
          </p>

          <figure className="app-window">
            <div className="win" aria-hidden="true">
              <div className="win-bar">
                <span className="dot dot-r" />
                <span className="dot dot-y" />
                <span className="dot dot-g" />
                <span className="win-title">AI Shell Switch</span>
              </div>
              <div className="win-body">
                <div className="win-head">
                  <Image src="/app-icon.png" alt="" width={48} height={48} />
                  <div>
                    <strong>AI Shell Switch</strong>
                    <span>蓋を閉じている間のAI稼働を、安全に切り替えます</span>
                  </div>
                </div>
                <p className="win-status">AI OFF</p>
                <p className="win-detail">
                  普通のmacOSスリープ設定です。蓋を閉じると通常どおりスリープできます。
                </p>
                <p className="win-power">電源: AC Power</p>
                <div className="win-buttons">
                  <span className="mac-btn">AI稼働モードにする(ON)</span>
                  <span className="mac-btn">状態を更新</span>
                </div>
                <p className="win-foot">⌃⌥A: 操作画面を開く / ON中は緊急OFF</p>
              </div>
            </div>
            <figcaption>
              アプリの操作画面(HTMLで再現したもの。実際の表示はmacOSの設定により多少異なります)
            </figcaption>
          </figure>
        </section>

        <hr />

        <section>
          <h2>何をするのか</h2>
          <p>
            {"扱うのは、macOSがもともと持っているスリープ設定("}
            <code>SleepDisabled</code>
            {")ひとつだけです。ONにするとスリープを止め、OFFにすると元に戻す。それ以上のことはしません。"}
          </p>
          <ul className="plain">
            <li>
              Macアプリ・メニューバー・CLIのどこから操作しても、同じ設定値を読み書きします。UIとターミナルで状態が食い違いません。
            </li>
            <li>AIタスクの起動・監視・スケジューリングは行いません。</li>
            <li>
              データはMacの外に出ません。ネットワーク通信も計測もありません。
            </li>
          </ul>
        </section>

        <section>
          <h2>スリープ禁止そのものは、macOSだけでもできます</h2>
          <p>
            <code>pmset</code> や <code>caffeinate</code>{" "}
            {"を使えば、Macのスリープはもともと止められます。ただ、止めたまま戻し忘れると、発熱やバッテリーの消耗が静かに進みます。"}
          </p>
          <p>
            {"だから AI Shell Switch は、止める機能ではなく「切り替えやすさ」を中心に作っています。"}
            <code>ai-on</code> と <code>ai-off</code>{" "}
            {"のひとことで確実に行き来できて、いまの状態はアプリでもメニューバーでも確認できる。ONの条件は絞り、OFFはいつでもできる。長時間処理を日常的に回すほど、この差が効いてきます。"}
          </p>
        </section>

        <section>
          <h2>ターミナルからも同じことができます</h2>
          <p>
            コマンドは5つだけです。スクリプトやエージェントのワークフローにそのまま組み込めます。
          </p>
          <div className="terminal-frame">
            <div className="term-bar" aria-hidden="true">
              <span className="dot dot-r" />
              <span className="dot dot-y" />
              <span className="dot dot-g" />
              <span className="term-title">ai-shell-switch — zsh</span>
            </div>
            <pre className="terminal">
              <code>
                <span className="prompt">$</span>
                {" ai-status\nAIクラムシェル運転: READY\n電源: AC Power\n"}
                <span className="prompt">$</span>
                {" ai-on"}
              </code>
            </pre>
          </div>
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
          <h2>安全のために決めていること</h2>
          <p>
            スリープを止める機能は、使い方しだいで発熱やバッテリーの消耗につながります。そこで、最初から次の3つを決めています。
          </p>
          <ul className="plain">
            <li>
              <strong>ONにできるのは、AC電源につながっているときだけ。</strong>
              バッテリー駆動中に新しくONにすることはできません。
            </li>
            <li>
              <strong>OFFはいつでもできます。</strong>
              ショートカット ⌃⌥A で、すぐにいつものスリープへ戻せます。
            </li>
            <li>
              <strong>
                管理者権限で実行するのは <code>pmset</code> の
                SleepDisabled(0と1)だけ。
              </strong>
              ほかのコマンドは許可していません。
            </li>
          </ul>
        </section>

        <hr />

        <section id="install">
          <h2>インストール</h2>
          <p>
            Xcode Command Line Tools を使って、自分のMacでビルドします。手順は3つです。
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
            {"いまはまだ、Developer IDでの署名やAppleによる公証を行っていない、ソース配布の段階です。初回起動時にmacOSの確認が出ることがあります("}
            <a
              href="https://support.apple.com/en-us/102445"
              target="_blank"
              rel="noreferrer"
            >
              Appleの解説
            </a>
            {")。ソースはすべて公開しているので、中身を確かめてからビルドできます。"}
          </p>
        </section>

        <section>
          <h2>知っておいてほしいこと</h2>
          <ul className="plain">
            <li>macOS専用です。WindowsやLinuxには対応していません。</li>
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
