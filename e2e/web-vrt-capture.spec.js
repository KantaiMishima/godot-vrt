const { test } = require("@playwright/test");

// Godot Web エクスポートをヘッドレスブラウザで実行する。
// スクリーンショットはランナー(vrt_runner.gd)が同一オリジンのローカル
// サーバーへ HTTP POST でアップロードするため、ここでは仮想 FS を読み出さず
// "=== Done ===" の出力を待つだけでよい。
test("run Godot Web export and upload screenshots", async ({ page }) => {
  const consoleLogs = [];
  const pageErrors = [];

  page.on("console", (msg) => {
    const text = msg.text();
    consoleLogs.push(`[${msg.type()}] ${text}`);
    console.log(`[browser ${msg.type()}] ${text}`);
  });

  page.on("pageerror", (err) => {
    pageErrors.push(err.message);
    console.error("[pageerror]", err.message);
  });

  const donePromise = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      console.error("=== Timeout Debug Info ===");
      console.error(`Console logs collected: ${consoleLogs.length}`);
      consoleLogs.forEach((log) => console.error(`  ${log}`));
      if (pageErrors.length > 0) {
        console.error(`Page errors: ${pageErrors.length}`);
        pageErrors.forEach((err) => console.error(`  ${err}`));
      }
      reject(new Error("Godot did not print '=== Done ===' within timeout"));
    }, 600_000);

    page.on("console", (msg) => {
      if (msg.text().includes("=== Done ===")) {
        clearTimeout(timeout);
        resolve();
      }
    });
  });

  console.log("Navigating to Godot Web export...");
  const response = await page.goto("/");
  console.log(`Page response status: ${response?.status()}`);

  await donePromise;

  // アップロード(POST)が完了するまで少し待つ
  await page.waitForTimeout(2000);
  console.log("Godot finished; screenshots uploaded via HTTP POST.");
});
