import Image from "next/image";

const repositoryUrl = "https://github.com/sheer-jp/ai-shell-switch";
const sourceZipUrl =
  "https://github.com/sheer-jp/ai-shell-switch/archive/refs/heads/main.zip";

const features = [
  {
    tag: "LIVE STATE",
    title: "いまの状態を、1秒で把握。",
    body: "macOSの実値からAI ON / OFFを判定。メニューバーとコントロール画面が、常に同じ状態を表示します。",
    type: "state",
  },
  {
    tag: "ONE TAP",
    title: "電源ポリシーを即切替。",
    body: "作業中だけスリープを停止。終わったらOFFで、macOS本来のスリープへ戻せます。",
    type: "switch",
  },
  {
    tag: "CLI NATIVE",
    title: "AIワークフローとつながる。",
    body: "ai-on、ai-off、ai-status。ターミナル中心のローカルエージェント運用にも自然に組み込めます。",
    type: "terminal",
  },
  {
    tag: "SAFE BY DEFAULT",
    title: "止める操作を、最優先に。",
    body: "新規ONはAC接続中だけ。OFFはいつでも実行でき、ショートカットから即座に通常スリープへ戻せます。",
    type: "safe",
  },
];

const steps = [
  ["01", "CONNECT", "電源を接続", "AI ONはAC電源接続中だけ。長時間処理の前提を安全側に固定します。"],
  ["02", "ACTIVATE", "AIモードをON", "アプリ、メニューバー、CLIの好きな入口からスリープ禁止を有効にします。"],
  ["03", "RESTORE", "完了したらOFF", "SleepDisabledを0へ戻し、いつものmacOSスリープ動作に復帰します。"],
];

export default function Home() {
  return (
    <main>
      <div className="noise" aria-hidden="true" />
      <div className="grid-bg" aria-hidden="true" />
      <div className="aurora aurora-one" aria-hidden="true" />
      <div className="aurora aurora-two" aria-hidden="true" />

      <nav className="nav shell" aria-label="メインナビゲーション">
        <a className="brand" href="#top" aria-label="AI Shell Switch トップへ">
          <span className="brand-icon">
            <Image src="/app-icon.png" alt="" width={34} height={34} priority />
          </span>
          <span>AI Shell Switch</span>
          <span className="open-badge">OPEN SOURCE</span>
        </a>
        <div className="nav-links">
          <a href="#product">Product</a>
          <a href="#workflow">Workflow</a>
          <a href="#trust">Trust</a>
          <a href="#install">Install</a>
        </div>
        <a className="nav-cta" href={repositoryUrl} target="_blank" rel="noreferrer">
          GitHub <span aria-hidden="true">↗</span>
        </a>
      </nav>

      <section className="hero shell" id="top">
        <div className="hero-copy">
          <a className="release-pill" href="#install">
            <i /> <strong>v1.3</strong> AI uptime control is live <span>→</span>
          </a>
          <p className="eyebrow">THE AI UPTIME LAYER FOR macOS</p>
          <h1>
            AIの実行環境を、
            <br />
            <span className="gradient-text">止めない。</span>
          </h1>
          <p className="hero-lead">
            Macのスリープ状態を、AIワークロードのために安全にコントロール。
            長時間のローカルエージェント、生成、解析を、ワンクリックで走り続けられる環境へ。
          </p>
          <div className="actions">
            <a className="button primary" href={sourceZipUrl}>
              無料でダウンロード <span>↓</span>
            </a>
            <a className="button ghost" href={repositoryUrl} target="_blank" rel="noreferrer">
              <b>⌘</b> ソースを見る
            </a>
          </div>
          <div className="hero-meta" aria-label="対応環境">
            <span><i /> Apple Silicon</span>
            <span><i /> macOS 13+</span>
            <span><i /> MIT License</span>
          </div>
          <p className="distribution-note">
            ソースZIPを自分のMac上でビルドする配布方式です。実際のクラムシェル動作は、
            機種・macOS・電源・外部ディスプレイなどの条件で異なります。
          </p>
        </div>

        <div className="hero-visual" aria-label="AI Shell Switch コントロールプレーン">
          <div className="orbit orbit-a"><i /><i /><i /></div>
          <div className="orbit orbit-b"><i /><i /></div>
          <div className="ai-core">
            <div className="core-ring" />
            <div className="core-icon">
              <Image src="/app-icon.png" alt="" width={112} height={112} priority />
            </div>
            <span>UPTIME CORE</span>
          </div>

          <div className="float-card agent-card">
            <div className="float-row">
              <span className="mini-ai">AI</span>
              <div><strong>Local agent</strong><small>Long-running task</small></div>
              <em>LIVE</em>
            </div>
            <div className="progress"><span /></div>
            <div className="progress-copy"><span>Processing context</span><strong>72%</strong></div>
          </div>

          <div className="float-card power-card">
            <span className="power-mark">⌁</span>
            <div><small>POWER SOURCE</small><strong>AC Connected</strong></div>
            <em>✓</em>
          </div>

          <div className="console">
            <div className="console-head">
              <div className="console-brand">
                <Image src="/app-icon.png" alt="" width={42} height={42} />
                <div><strong>AI Shell Switch</strong><span>CONTROL PLANE</span></div>
              </div>
              <span>•••</span>
            </div>
            <div className="status">
              <div><small>SYSTEM STATUS</small><strong><i /> AI MODE READY</strong></div>
              <span>SECURE</span>
            </div>
            <div className="metrics">
              <div><span>Sleep policy</span><strong>Standard</strong></div>
              <div><span>Power</span><strong className="cyan">AC</strong></div>
              <div><span>Control</span><strong className="lime">Ready</strong></div>
            </div>
            <div className="console-action">
              <span>◉</span>
              <div><strong>Activate AI uptime</strong><small>Keep this Mac available for local agents</small></div>
              <kbd>⌃⌥A</kbd>
            </div>
          </div>
        </div>
      </section>

      <section className="signal-bar">
        <div className="shell signals">
          <div><span>◈</span><strong>LOCAL FIRST</strong><small>データはMacの中に</small></div>
          <div><span>⌘</span><strong>CLI NATIVE</strong><small>自動化にそのまま接続</small></div>
          <div><span>AC</span><strong>POWER GUARDED</strong><small>ONはAC接続中だけ</small></div>
          <div><span>↙</span><strong>INSTANT OFF</strong><small>いつでも通常スリープへ</small></div>
        </div>
      </section>

      <section className="section shell" id="product">
        <div className="section-heading centered">
          <span className="section-label">PRODUCT INTELLIGENCE</span>
          <h2>ローカルAIに必要な<br /><span>“稼働し続ける”を、ひとつに。</span></h2>
          <p>
            複雑な設定を隠し、必要な状態・操作・安全境界だけを、
            一つのコントロールプレーンへまとめました。
          </p>
        </div>

        <div className="bento-grid">
          {features.map((feature) => (
            <article className={"bento-card " + feature.type} key={feature.tag}>
              <div className="bento-copy">
                <span className="bento-tag">{feature.tag}</span>
                <h3>{feature.title}</h3>
                <p>{feature.body}</p>
              </div>
              {feature.type === "state" && (
                <div className="state-visual" aria-hidden="true">
                  <div className="wave"><span /><span /><span /><span /><span /><span /><span /></div>
                  <div><span><i /> Uptime layer</span><strong>ACTIVE</strong></div>
                  <div><span><i className="violet-dot" /> Local agent</span><strong>RUNNING</strong></div>
                  <div><span><i className="cyan-dot" /> Power guard</span><strong>READY</strong></div>
                </div>
              )}
              {feature.type === "switch" && (
                <div className="switch-visual" aria-hidden="true">
                  <div><span /></div><small>AI UPTIME</small><strong>ON</strong>
                </div>
              )}
              {feature.type === "terminal" && (
                <div className="terminal" aria-hidden="true">
                  <div className="terminal-head"><i /><i /><i /><small>agent-control — zsh</small></div>
                  <code><b>$</b> ai-status</code>
                  <code><span>AIクラムシェル運転:</span> READY</code>
                  <code><span>電源:</span> AC Power</code>
                  <code><b>$</b> ai-on <em>_</em></code>
                </div>
              )}
              {feature.type === "safe" && (
                <div className="safe-visual" aria-hidden="true">
                  <span>✓</span>
                  <div><strong>3 safety layers</strong><small>AC guard · exact commands · instant OFF</small></div>
                </div>
              )}
            </article>
          ))}
        </div>
      </section>

      <section className="section workflow-section" id="workflow">
        <div className="shell">
          <div className="section-heading split">
            <div>
              <span className="section-label">ZERO-FRICTION WORKFLOW</span>
              <h2>3つの動作。<br /><span>迷わない運用。</span></h2>
            </div>
            <p>
              AIタスクの起動や監視は行いません。扱うのはmacOSのスリープ設定だけ。
              責務が小さいから、運用も復帰も明快です。
            </p>
          </div>
          <div className="workflow">
            {steps.map((step, index) => (
              <article key={step[0]}>
                <div className="step-node"><span>{step[0]}</span>{index < 2 && <i />}</div>
                <small>{step[1]}</small>
                <h3>{step[2]}</h3>
                <p>{step[3]}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="section shell">
        <div className="command-shell">
          <div className="command-copy">
            <span className="section-label">ONE CONTROL PLANE</span>
            <h2>アプリでも、CLIでも。<br />状態は、ひとつ。</h2>
            <p>
              どの入口から操作しても、見ているのは同じSleepDisabled値。
              UIとターミナルが食い違わない、シンプルな状態管理です。
            </p>
            <div className="command-pills">
              <span>ai-on</span><span>ai-off</span><span>ai-toggle</span><span>ai-status</span><span>ai-doctor</span>
            </div>
          </div>
          <div className="command-map" aria-hidden="true">
            <div className="map-node node-app"><Image src="/app-icon.png" alt="" width={48} height={48} /><span>Mac App</span></div>
            <div className="map-node node-menu"><strong>AI</strong><span>Menu Bar</span></div>
            <div className="map-node node-cli"><strong>&gt;_</strong><span>CLI</span></div>
            <div className="map-center"><i /><strong>SleepDisabled</strong><small>Single source of truth</small></div>
            <b className="map-line line-a" /><b className="map-line line-b" /><b className="map-line line-c" />
          </div>
        </div>
      </section>

      <section className="section trust-section" id="trust">
        <div className="shell trust-layout">
          <div className="trust-copy">
            <span className="section-label">TRUST LAYER</span>
            <h2>強い機能に、<br /><span>明確なガードレール。</span></h2>
            <p>
              スリープ禁止は便利ですが、使い方を誤ると発熱やバッテリー消費につながります。
              AI Shell Switchは、最初から安全側へ倒した操作設計です。
            </p>
            <a href="https://support.apple.com/en-us/102445" target="_blank" rel="noreferrer">
              Appleのアプリ安全性ガイド <span>↗</span>
            </a>
          </div>
          <div className="trust-stack">
            <article><span>01</span><div><h3>AC Power Guard</h3><p>バッテリー駆動中の新規ONをブロックします。</p></div><em>PROTECTED</em></article>
            <article><span>02</span><div><h3>Exact Command Scope</h3><p>許可する管理者コマンドは、pmsetの0と1だけです。</p></div><em>LIMITED</em></article>
            <article><span>03</span><div><h3>Instant Safe Exit</h3><p>OFFはいつでも実行可能。⌃⌥Aですぐ通常スリープへ。</p></div><em>ALWAYS ON</em></article>
          </div>
        </div>
      </section>

      <section className="section install-section" id="install">
        <div className="shell install-layout">
          <div className="install-copy">
            <span className="section-label">OPEN SOURCE · FREE FOREVER</span>
            <h2>あなたのMacに、<br /><span>AIの稼働レイヤーを。</span></h2>
            <p>
              Apple Silicon搭載Mac、macOS 13以降に対応。
              ソースを確認し、自分の環境でビルドして使えます。
            </p>
            <div className="price"><strong>¥0</strong><span>MIT License<br />No account required</span></div>
            <div className="actions">
              <a className="button primary" href={sourceZipUrl}>ソースZIPをダウンロード <span>↓</span></a>
              <a className="button ghost" href={repositoryUrl} target="_blank" rel="noreferrer">GitHub <span>↗</span></a>
            </div>
          </div>
          <div className="install-console">
            <div className="install-head"><span><i /><i /><i /></span><small>Quick install</small><b>⌘</b></div>
            <div className="install-line"><span>1</span><div><small>Developer Tools</small><code>xcode-select --install</code></div><em>✓</em></div>
            <div className="install-line"><span>2</span><div><small>Get the source</small><code>git clone https://github.com/sheer-jp/ai-shell-switch.git</code></div><em>✓</em></div>
            <div className="install-line"><span>3</span><div><small>Launch</small><code>cd ai-shell-switch<br />./install.sh</code></div><em>✓</em></div>
            <p>ZIPの場合は <code>~/Downloads/ai-shell-switch-main</code> へ移動し、<code>./install.sh</code> を実行します。</p>
          </div>
        </div>
      </section>

      <section className="boundary shell">
        <span>!</span>
        <div>
          <strong>Source distribution notice</strong>
          <p>
            現在はDeveloper IDで署名・公証された完成済みアプリではありません。
            Xcode Command Line Toolsを使い、各自のMac上でビルドします。
            ON時は電源アダプタと十分な通気を確保してください。
          </p>
        </div>
        <div className="specs"><span>Apple Silicon</span><span>macOS 13+</span><span>Xcode CLI Tools</span></div>
      </section>

      <section className="final-cta">
        <div className="final-orb" aria-hidden="true"><span /></div>
        <div className="shell final-content">
          <span className="section-label">KEEP THE INTELLIGENCE RUNNING</span>
          <h2>次のAIタスクを、<br /><span className="gradient-text">止めないMacへ。</span></h2>
          <p>無料・オープンソース。アカウント登録は必要ありません。</p>
          <div className="actions">
            <a className="button primary" href={sourceZipUrl}>無料で始める <span>→</span></a>
            <a className="button ghost" href={repositoryUrl} target="_blank" rel="noreferrer">GitHubで見る <span>↗</span></a>
          </div>
        </div>
      </section>

      <footer>
        <div className="shell footer-inner">
          <div className="brand"><span className="brand-icon"><Image src="/app-icon.png" alt="" width={30} height={30} /></span><span>AI Shell Switch</span></div>
          <p>Local-first uptime control for AI workloads on macOS.</p>
          <div className="footer-links"><a href={repositoryUrl}>GitHub</a><a href={repositoryUrl + "/blob/main/LICENSE"}>MIT License</a><a href="#top">Back to top ↑</a></div>
        </div>
      </footer>
    </main>
  );
}
