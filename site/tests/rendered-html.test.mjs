import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

async function render(path = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`https://ai-shell-switch.example${path}`, {
      headers: {
        accept: "text/html",
        host: "ai-shell-switch.example",
        "x-forwarded-host": "ai-shell-switch.example",
        "x-forwarded-proto": "https",
      },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the finished Japanese distribution page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<html[^>]+lang="ja"/i);
  assert.match(html, /AI Shell Switch/);
  assert.match(html, /Macを閉じても/);
  assert.match(html, /ソースZIPをダウンロード/);
  assert.match(html, /Apple Silicon/);
  assert.match(html, /macOS 13\+/);
  assert.match(html, /Xcode Command Line Tools/);
  assert.match(html, /現在は、ソース配布です/);
  assert.match(
    html,
    /https:\/\/github\.com\/sheer-jp\/ai-shell-switch\/archive\/refs\/heads\/main\.zip/,
  );
  assert.match(
    html,
    /https:\/\/github\.com\/sheer-jp\/ai-shell-switch/,
  );
  assert.match(html, /https:\/\/ai-shell-switch\.example\/og\.png/);
  assert.match(
    html,
    /<link[^>]+rel="canonical"[^>]+href="https:\/\/ai-shell-switch\.bonahja\.chatgpt\.site"/i,
  );
  assert.doesNotMatch(html, /Starter Project|codex-preview|SkeletonPreview/);
});

test("publishes robots and sitemap metadata routes", async () => {
  const [robots, sitemapResponse] = await Promise.all([
    readFile(new URL("../public/robots.txt", import.meta.url), "utf8"),
    render("/sitemap.xml"),
  ]);

  assert.match(robots, /Sitemap: https:\/\/ai-shell-switch\.bonahja\.chatgpt\.site\/sitemap\.xml/);
  assert.equal(sitemapResponse.status, 200);
  assert.match(await sitemapResponse.text(), /https:\/\/ai-shell-switch\.bonahja\.chatgpt\.site/);
});

test("keeps distribution assets and source contracts explicit", async () => {
  const [page, layout, packageJson] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
  ]);

  await access(new URL("../public/app-icon.png", import.meta.url));
  await access(new URL("../public/og.png", import.meta.url));
  await assert.rejects(access(new URL("../app/_sites-preview", root)));

  assert.match(page, /xcode-select --install/);
  assert.match(page, /\.\/install\.sh/);
  assert.match(page, /Developer IDで署名・公証された完成済みアプリではありません/);
  assert.match(layout, /generateMetadata/);
  assert.match(layout, /metadataBase/);
  assert.match(layout, /lang="ja"/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
});
