import { describe, expect, it } from "vitest";

import { bookingReference, businessDate, nextBusinessDate, statusLabel } from "./format";

describe("booking formatters", () => {
  it("creates a short readable reference", () => {
    expect(bookingReference("12345678-abcd-efgh-ijkl-1234567890ab")).toBe("SD-12345678");
  });

  it("moves weekend dates to Monday", () => {
    expect(nextBusinessDate(new Date("2026-08-07T12:00:00Z"))).toBe("2026-08-10");
  });

  it("uses the business timezone at the UTC date boundary", () => {
    expect(businessDate(new Date("2026-08-08T02:00:00Z"))).toBe("2026-08-07");
  });

  it("labels statuses", () => {
    expect(statusLabel("confirmed")).toBe("Confirmed");
  });
});
