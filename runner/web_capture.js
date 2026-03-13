#!/usr/bin/env node
/**
 * web_capture.js — Playwright を使った Web エクスポート用 VRT キャプチャスクリプト
 *
 * ## 概要
 * Godot Web エクスポート（HTML5）を起動し、platform_runner.gd が全シーンのキャプチャを
 * 完了したら `window.__VRT_SCREENSHOTS__` から画像データを取得して保存する。
 *
 * ## 前提
 * - Node.js 18+
 * - @playwright/test パッケージのインストール: npm install @playwright/test
 * - 事前に Godot の Web エクスポートを実行済みで exports/web/index.html が存在すること
 * - serve パッケージ (npx serve) または任意の HTTP サーバーでエクスポートを配信すること
 *
 * ## 使い方
 *
 * ```bash
 * # HTTP サーバーを起動（別ターミナルで）
 * npx serve exports/web -p 8080
 *
 * # キャプチャ実行（全シーン）
 * node runner/web_capture.js
 *
 * # キャプチャ実行（特定シーンのみ）
 * node runner/web_capture.js res://web_ui_test.tscn,res://button_test.tscn
 * ```
 *
 * ## 出力
 * 画像は tests/vr_screenshots/ に保存される。
 */

const { chromium } = require('@playwright/test');
const path = require('path');
const fs = require('fs');

const BASE_URL = process.env.VRT_WEB_URL || 'http://localhost:8080';
const OUTPUT_DIR = process.env.VRT_OUTPUT_DIR || path.join(__dirname, '..', 'tests', 'vr_screenshots');
const TIMEOUT_MS = parseInt(process.env.VRT_TIMEOUT_MS || '120000', 10);
const scenes = process.argv[2] || '';

async function main() {
  console.log('=== Godot VRT Web Capture ===');
  console.log('Base URL:', BASE_URL);
  console.log('Output:', OUTPUT_DIR);

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
  });
  const page = await context.newPage();

  // コンソールログを転送
  page.on('console', (msg) => {
    console.log('[godot]', msg.text());
  });

  const url = scenes ? `${BASE_URL}?scenes=${encodeURIComponent(scenes)}` : BASE_URL;
  console.log('Navigating to:', url);

  await page.goto(url);

  // Godot の起動と VRT 完了を待機
  console.log(`Waiting for VRT completion (timeout: ${TIMEOUT_MS}ms)...`);
  try {
    await page.waitForFunction(
      () => window.__VRT_DONE__ === true || window.__VRT_DONE__ === false,
      { timeout: TIMEOUT_MS }
    );
  } catch (e) {
    console.error('Timeout waiting for VRT completion:', e.message);
    await browser.close();
    process.exit(1);
  }

  const success = await page.evaluate(() => window.__VRT_DONE__);
  if (!success) {
    console.error('VRT runner reported failure.');
    await browser.close();
    process.exit(1);
  }

  // スクリーンショットを JavaScript 側から取得
  // platform_runner.gd の _maybe_push_to_web() が window.__VRT_SCREENSHOTS__ に格納している前提
  const screenshots = await page.evaluate(() => window.__VRT_SCREENSHOTS__ || {});
  const names = Object.keys(screenshots);

  if (names.length === 0) {
    // フォールバック: Godot の user:// に保存されたファイルが取れない場合は
    // ページ全体のスクリーンショットを撮影する
    console.warn('No screenshots from runner. Falling back to page screenshot.');
    const fallback = path.join(OUTPUT_DIR, 'web_fallback.png');
    await page.screenshot({ path: fallback, fullPage: false });
    console.log('Saved:', fallback);
  } else {
    for (const [name, dataUrl] of Object.entries(screenshots)) {
      const base64 = dataUrl.replace(/^data:image\/png;base64,/, '');
      const buf = Buffer.from(base64, 'base64');
      const filePath = path.join(OUTPUT_DIR, name);
      fs.writeFileSync(filePath, buf);
      console.log('Saved:', filePath);
    }
  }

  console.log('=== Done ===');
  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
