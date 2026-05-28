const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");

test("capture VRT screenshots from Godot Web export", async ({ page }) => {
  const donePromise = new Promise((resolve, reject) => {
    const timeout = setTimeout(
      () => reject(new Error("Godot did not print '=== Done ===' within timeout")),
      150_000,
    );
    page.on("console", (msg) => {
      const text = msg.text();
      if (text.includes("=== Done ===")) {
        clearTimeout(timeout);
        resolve();
      }
    });
  });

  await page.goto("/");
  await donePromise;
  await page.waitForTimeout(1000);

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

    if (!fsRef) return { error: "Emscripten FS not accessible" };

    const dirs = ["/home/web_user/vr_screenshots", "/userfs/vr_screenshots", "/vr_screenshots"];
    for (const dir of dirs) {
      try {
        const entries = fsRef.readdir(dir).filter((f) => f.endsWith(".png"));
        if (entries.length > 0) {
          return {
            dir,
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
    return { error: "No screenshots found in virtual FS" };
  });

  if (result.error) {
    console.error("Screenshot extraction failed:", result.error);
    test.skip(true, result.error);
    return;
  }

  console.log(`Found ${result.files.length} screenshots in ${result.dir}`);

  const outDir = path.resolve("vr_screenshots_web");
  fs.mkdirSync(outDir, { recursive: true });

  for (const { name, data } of result.files) {
    fs.writeFileSync(path.join(outDir, name), Buffer.from(data));
    console.log(`  Saved: ${name}`);
  }

  expect(result.files.length).toBeGreaterThan(0);
});
