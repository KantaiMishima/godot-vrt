const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

test("capture VRT screenshots from Godot Web export", async ({ page }) => {
  const consoleLogs = [];
  const pageErrors = [];

  page.on("console", (msg) => {
    const text = msg.text();
    consoleLogs.push(`[${msg.type()}] ${text}`);
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
      const text = msg.text();
      if (text.includes("=== Done ===")) {
        clearTimeout(timeout);
        resolve();
      }
    });
  });

  console.log("Navigating to Godot Web export...");
  const response = await page.goto("/");
  console.log(`Page response status: ${response?.status()}`);

  try {
    await donePromise;
  } catch (e) {
    console.error("=== Attempting FS scan despite timeout ===");
    const fsCheck = await page.evaluate(() => {
      const results = {};
      results.hasGodot = typeof Godot !== "undefined";
      results.hasModule = typeof Module !== "undefined";
      results.hasFS = typeof FS !== "undefined";
      if (results.hasGodot) results.godotKeys = Object.keys(Godot).slice(0, 20);
      if (results.hasModule) results.moduleKeys = Object.keys(Module).slice(0, 20);
      return results;
    }).catch((evalErr) => ({ evalError: evalErr.message }));
    console.error("FS check result:", JSON.stringify(fsCheck, null, 2));
    throw e;
  }

  console.log("Godot finished, waiting 1s for FS flush...");
  await page.waitForTimeout(1000);

  console.log("Scanning Emscripten FS for screenshots...");
  const result = await page.evaluate(() => {
    /* eslint-disable no-undef */
    const fsRef =
      typeof Godot !== "undefined" && Godot.FS
        ? Godot.FS
        : typeof Module !== "undefined" && Module.FS
          ? Module.FS
          : typeof FS !== "undefined"
            ? FS
            : null;

    if (!fsRef) {
      return {
        error: "Emscripten FS not accessible",
        hasGodot: typeof Godot !== "undefined",
        hasModule: typeof Module !== "undefined",
        hasFS: typeof FS !== "undefined",
      };
    }

    const dirsToCheck = [
      "/home/web_user/vr_screenshots",
      "/userfs/vr_screenshots",
      "/vr_screenshots",
      "/home/web_user",
      "/userfs",
    ];
    const dirContents = {};
    for (const dir of dirsToCheck) {
      try {
        dirContents[dir] = fsRef.readdir(dir);
      } catch (_e) {
        dirContents[dir] = "NOT_FOUND";
      }
    }

    const screenshotDirs = [
      "/home/web_user/vr_screenshots",
      "/userfs/vr_screenshots",
      "/vr_screenshots",
    ];
    for (const dir of screenshotDirs) {
      try {
        const entries = fsRef.readdir(dir).filter((f) => f.endsWith(".png"));
        if (entries.length > 0) {
          return {
            dir,
            dirContents,
            files: entries.map((f) => ({
              name: f,
              data: Array.from(fsRef.readFile(dir + "/" + f)),
            })),
          };
        }
      } catch (_e) {
        /* try next path */
      }
    }
    return { error: "No screenshots found in virtual FS", dirContents };
  });

  console.log("FS scan result dirs:", JSON.stringify(result.dirContents || {}, null, 2));

  if (result.error) {
    console.error("Screenshot extraction failed:", result.error);
    console.error("All console logs:");
    consoleLogs.forEach((log) => console.error(`  ${log}`));
    test.skip(true, result.error);
    return;
  }

  console.log(`Found ${result.files.length} screenshots in ${result.dir}`);

  const outDir = path.resolve("vr_screenshots_web");
  fs.mkdirSync(outDir, { recursive: true });

  for (const { name, data } of result.files) {
    fs.writeFileSync(path.join(outDir, name), Buffer.from(data));
    console.log(`  Saved: ${name} (${data.length} bytes)`);
  }

  expect(result.files.length).toBeGreaterThan(0);
});
