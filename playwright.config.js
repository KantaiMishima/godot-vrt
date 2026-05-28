const { defineConfig } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "./e2e",
  timeout: 180_000,
  use: {
    baseURL: "http://localhost:8080",
    headless: true,
  },
});
