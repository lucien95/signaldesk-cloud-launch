import { defineConfig, devices } from "@playwright/test";

const python = process.env.PYTHON_BIN ?? "python";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? [["line"], ["html", { open: "never" }]] : "line",
  use: {
    baseURL: "http://127.0.0.1:8090",
    trace: "on-first-retry",
  },
  webServer: {
    command:
      `PYTHONPATH=. FRONTEND_DIR=frontend/out DATABASE_URL=sqlite+pysqlite:///:memory: ${python} -m uvicorn signaldesk.main:app --host 127.0.0.1 --port 8090`,
    cwd: "..",
    url: "http://127.0.0.1:8090/health/live",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "mobile", use: { ...devices["Pixel 7"] } },
  ],
});
