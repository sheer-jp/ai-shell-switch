import Image from "next/image";

const repositoryUrl = "https://github.com/sheer-jp/ai-shell-switch";
const sourceZipUrl =
  "https://github.com/sheer-jp/ai-shell-switch/archive/refs/heads/main.zip";

const features = [
  {
    number: "01",
    title: "状態がひと目で分かる",
    body: "メニューバーと操作画面に、実際のSleepDisabled値から判定したAI ON / OFFを表示します。",
  },
  {
    number: "02",
    title: "通常スリープへ即復帰",
    body: "作業が終わったらOFF。macOS本来のスリープ動作へ、いつでも戻せます。",
  },
  {
    number: "03",
    title: "ターミナルでも操作",
    body: "ai-on、ai-off、ai-status。自動処理やシェル中心の作業にも、そのまま組み込めます。",
  },
];

const installSteps = [
  {
    number: "1",
    title: "準備する",
    body: "初回だけ、AppleのCommand Line Toolsを入れます。すでにSwift開発環境があるMacでは不要です。",
    code: "xcode-select --install",
  },
  {
    number: "2",
    title: "ソースを取得",
    body: "上のボタンからZIPをダウンロードして展開するか、Gitでcloneします。",
    code: "git clone https://github.com/sheer-jp/ai-shell-switch.git",
  },
  {
    number: "3",
    title: "インストール",
    body: "展開またはcloneしたフォルダへ移動し、インストーラーを実行します。アプリは自分のMac上でビルドされます。",
    code: "# ZIPの場合\ncd ~/Downloads/ai-shell-switch-main\n\n# cloneの場合\ncd ai-shell-switch\n\n./install.sh",
  },
];

export default function Home() {
  return (
    <main>
      <div className="ambient ambient-one" aria-hidden="true" />
      <div className="ambient ambient-two" aria-hidden="true" />

      <nav className="nav site-shell" aria-label="メインナビゲーション">
        <a className="brand" href="#top" aria-label="AI Shell Switch トップへ">
          <Image src="/app-icon.png" alt="" width={36} height={36} />
          <span>AI Shell Switch</span>
        </a>
        <div className="nav-links">
          <a href="#install">インストール</a>
          <a href="#safety">安全設計</a>
          <a
            className="nav-github"
            href={repositoryUrl}
            target="_blank"
            rel="noreferrer"
          >
            GitHub <span aria-hidden="true">↗</span>
          </a>
        </div>
      </nav>

      <section className="hero site-shell" id="top">
        <div className="hero-copy">
          <div className="eyebrow">
            <span className="live-dot" aria-hidden="true" />
            Open source macOS utility
          </div>
          <h1>
            Macを閉じても、
            <br />
            <span>AIの作業を止めない。</span>
          </h1>
          <p className="hero-lead">
            必要なときだけMacのスリープを止め、終わったらすぐ元へ戻す。
            ローカルAI作業のための、小さくて明快なメニューバースイッチです。
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href={sourceZipUrl}>
              ソースZIPをダウンロード
              <span aria-hidden="true">↓</span>
            </a>
            <a
              className="button button-secondary"
              href={repositoryUrl}
              target="_blank"
              rel="noreferrer"
            >
              GitHubで中身を見る
              <span aria-hidden="true">↗</span>
            </a>
          </div>
          <div className="compatibility" aria-label="対応環境">
            <span>macOS 13+</span>
            <span>Apple Silicon</span>
            <span>MIT License</span>
          </div>
          <p className="distribution-note">
            完成済みバイナリではなく、公開ソースを各自のMac上でビルドする配布方式です。
            実際のクラムシェル動作は機種・macOS・電源・外部ディスプレイなどの条件で異なります。
          </p>
        </div>

        <div className="product-stage" aria-label="AI Shell Switch 操作画面のイメージ">
          <div className="orbit orbit-one" aria-hidden="true" />
          <div className="orbit orbit-two" aria-hidden="true" />
          <div className="app-window">
            <div className="window-bar">
              <div className="traffic-lights" aria-hidden="true">
                <span />
                <span />
                <span />
              </div>
              <span>AI Shell Switch</span>
              <span className="window-spacer" />
            </div>
            <div className="window-body">
              <div className="app-heading">
                <Image src="/app-icon.png" alt="" width={64} height={64} />
                <div>
                  <strong>AI Shell Switch</strong>
                  <span>LOCAL POWER CONTROL</span>
                </div>
              </div>
              <div className="state-card">
                <div className="state-row">
                  <div>
                    <span className="state-label">CURRENT STATE</span>
                    <strong>AI OFF</strong>
                  </div>
                  <span className="state-pill">SAFE</span>
                </div>
                <p>通常のmacOSスリープ設定です。</p>
                <div className="power-row">
                  <span>電源</span>
                  <strong>
                    <span className="power-dot" aria-hidden="true" />
                    AC Power
                  </strong>
                </div>
              </div>
              <div className="mock-actions" aria-hidden="true">
                <span>AI稼働モードにする</span>
                <span>状態を更新</span>
              </div>
              <div className="shortcut">
                <kbd>⌃</kbd>
                <kbd>⌥</kbd>
                <kbd>A</kbd>
                <span>操作画面 / 緊急OFF</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="proof-strip">
        <div className="site-shell proof-grid">
          <div>
            <strong>2</strong>
            <span>許可する管理者コマンドだけ</span>
          </div>
          <div>
            <strong>AC</strong>
            <span>ONは電源接続中だけ</span>
          </div>
          <div>
            <strong>OFF</strong>
            <span>いつでも通常スリープへ</span>
          </div>
          <div>
            <strong>¥0</strong>
            <span>無料・MITライセンス</span>
          </div>
        </div>
      </section>

      <section className="section site-shell" id="features">
        <div className="section-heading">
          <span className="section-kicker">WHY AI SHELL SWITCH</span>
          <h2>やることは、ひとつだけ。</h2>
          <p>
            macOSのスリープ禁止を、安全にON/OFFする。
            AIタスクそのものには触れず、電源状態だけを分かりやすく扱います。
          </p>
        </div>
        <div className="feature-grid">
          {features.map((feature) => (
            <article className="feature-card" key={feature.number}>
              <span className="feature-number">{feature.number}</span>
              <h3>{feature.title}</h3>
              <p>{feature.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="section install-section" id="install">
        <div className="site-shell">
          <div className="section-heading install-heading">
            <span className="section-kicker">INSTALL FROM GITHUB</span>
            <h2>3ステップで、自分のMacへ。</h2>
            <p>
              ソースコードはすべてGitHubで公開。ダウンロードした内容を、
              あなたのMac上でビルドしてインストールします。
            </p>
          </div>
          <div className="install-grid">
            {installSteps.map((step) => (
              <article className="install-card" key={step.number}>
                <div className="step-top">
                  <span>{step.number}</span>
                  <h3>{step.title}</h3>
                </div>
                <p>{step.body}</p>
                <pre>
                  <code>{step.code}</code>
                </pre>
              </article>
            ))}
          </div>
          <div className="install-cta">
            <div>
              <strong>AI Shell Switch — source edition</strong>
              <span>mainブランチの最新版をダウンロード</span>
            </div>
            <a className="button button-primary" href={sourceZipUrl}>
              ZIPをダウンロード
              <span aria-hidden="true">↓</span>
            </a>
          </div>
        </div>
      </section>

      <section className="section site-shell safety-section" id="safety">
        <div className="safety-copy">
          <span className="section-kicker">SAFETY BY DESIGN</span>
          <h2>強い機能だから、境界を明確に。</h2>
          <p>
            ONはMacのスリープを禁止します。だからこそ、電源・OFF・権限の
            3つを最初から安全側へ倒しています。
          </p>
          <a
            href="https://support.apple.com/en-us/102445"
            target="_blank"
            rel="noreferrer"
          >
            Appleのアプリ安全性ガイドを見る <span aria-hidden="true">↗</span>
          </a>
        </div>
        <div className="safety-panel">
          <div className="safety-item">
            <span className="safety-icon">AC</span>
            <div>
              <h3>電源アダプタ接続中だけON</h3>
              <p>バッテリー駆動中の新規ONをアプリ側で止めます。</p>
            </div>
          </div>
          <div className="safety-item">
            <span className="safety-icon">2×</span>
            <div>
              <h3>許可コマンドは2つだけ</h3>
              <p>
                パスワード省略設定が許可するのは、disablesleepの0と1だけです。
              </p>
            </div>
          </div>
          <div className="safety-item">
            <span className="safety-icon">OFF</span>
            <div>
              <h3>ショートカットは安全側へ</h3>
              <p>OFF中は画面を開くだけ。ON中は⌃⌥AですぐOFFへ戻せます。</p>
            </div>
          </div>
        </div>
      </section>

      <section className="section site-shell boundary-section">
        <div className="boundary-card">
          <div>
            <span className="section-kicker">BEFORE YOU INSTALL</span>
            <h2>現在は、ソース配布です。</h2>
          </div>
          <div className="boundary-copy">
            <p>
              このリリースはDeveloper IDで署名・公証された完成済みアプリではありません。
              GitHubからソースを取得し、各自のMacでビルドします。
            </p>
            <p>
              本アプリが切り替えるのはスリープ設定だけです。AIタスクの起動・監視・再開は行いません。
              クラムシェル動作の可否はMac本体と接続環境に依存します。
            </p>
            <ul>
              <li>Apple Silicon搭載Mac</li>
              <li>macOS 13以降</li>
              <li>Xcode Command Line Tools</li>
              <li>ON時は電源アダプタと十分な通気</li>
            </ul>
          </div>
        </div>
      </section>

      <section className="final-cta">
        <div className="site-shell">
          <Image src="/app-icon.png" alt="" width={88} height={88} />
          <span className="section-kicker">READY WHEN YOU ARE</span>
          <h2>AIの長い仕事を、Macに任せよう。</h2>
          <p>無料・オープンソース。中身を見て、自分のMacへ。</p>
          <div className="hero-actions final-actions">
            <a className="button button-primary" href={sourceZipUrl}>
              ソースZIPをダウンロード
              <span aria-hidden="true">↓</span>
            </a>
            <a
              className="button button-secondary"
              href={repositoryUrl}
              target="_blank"
              rel="noreferrer"
            >
              GitHubを開く
              <span aria-hidden="true">↗</span>
            </a>
          </div>
        </div>
      </section>

      <footer>
        <div className="site-shell footer-inner">
          <div className="brand footer-brand">
            <Image src="/app-icon.png" alt="" width={32} height={32} />
            <span>AI Shell Switch</span>
          </div>
          <p>Built for long-running local AI work on Mac.</p>
          <div className="footer-links">
            <a href={repositoryUrl}>GitHub</a>
            <a href={`${repositoryUrl}/blob/main/LICENSE`}>MIT License</a>
          </div>
        </div>
      </footer>
    </main>
  );
}
