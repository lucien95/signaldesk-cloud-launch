import { expect, test } from "@playwright/test";

function nextWeekday(): string {
  const date = new Date();
  date.setDate(date.getDate() + 2);
  while (date.getDay() === 0 || date.getDay() === 6) date.setDate(date.getDate() + 1);
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, "0"),
    String(date.getDate()).padStart(2, "0"),
  ].join("-");
}

test("customer booking reaches the operations board", async ({ page }, testInfo) => {
  const customerName = `SignalOps E2E ${testInfo.project.name}`;
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Schedule the work. Keep every promise." })).toBeVisible();
  await expect(page.getByText("Platform ready")).toBeVisible();

  await page.getByLabel("Full name").fill(customerName);
  await page.getByLabel("Email address").fill("signalops-e2e@example.com");
  await page.getByLabel("Appointment date").fill(nextWeekday());

  const availableSlot = page.getByRole("button", { name: /Available/ }).first();
  await expect(availableSlot).toBeEnabled();
  await availableSlot.click();
  await page.getByRole("button", { name: "Confirm appointment" }).click();

  await expect(page.getByTestId("confirmation")).toContainText("Appointment confirmed");
  await expect(page.getByTestId("confirmation")).toContainText("Request ID");

  await page.getByRole("tab", { name: "Operations board" }).click();
  const bookingCard = page.getByTestId("booking-card").filter({ hasText: customerName });
  await expect(bookingCard).toBeVisible();

  page.once("dialog", (dialog) => dialog.accept());
  await bookingCard.getByRole("button", { name: "Mark complete" }).click();
  await expect(bookingCard.getByText("Completed", { exact: true })).toBeVisible();
  await expect(page.getByRole("status").filter({ hasText: "is now completed" })).toBeVisible();
});
