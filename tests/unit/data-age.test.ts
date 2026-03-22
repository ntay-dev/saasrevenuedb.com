import { describe, it, expect } from "vitest";
import { differenceInMonths, parseISO } from "date-fns";

// Test the data age / stale detection logic (mirrors DataAge.vue)
function isStale(sourcedAt: string | null, staleMonths = 6): boolean {
  if (!sourcedAt) return false;
  try {
    const date = parseISO(sourcedAt);
    return differenceInMonths(new Date(), date) >= staleMonths;
  } catch {
    return false;
  }
}

describe("data age / stale detection", () => {
  it("returns false for null", () => {
    expect(isStale(null)).toBe(false);
  });

  it("returns false for recent date", () => {
    const recent = new Date();
    recent.setDate(recent.getDate() - 10);
    expect(isStale(recent.toISOString())).toBe(false);
  });

  it("returns false for date 5 months ago", () => {
    const fiveMonthsAgo = new Date();
    fiveMonthsAgo.setMonth(fiveMonthsAgo.getMonth() - 5);
    expect(isStale(fiveMonthsAgo.toISOString())).toBe(false);
  });

  it("returns true for date 6 months ago", () => {
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 7);
    expect(isStale(sixMonthsAgo.toISOString())).toBe(true);
  });

  it("returns true for date 1 year ago", () => {
    const yearAgo = new Date();
    yearAgo.setFullYear(yearAgo.getFullYear() - 1);
    expect(isStale(yearAgo.toISOString())).toBe(true);
  });

  it("respects custom stale threshold", () => {
    const threeMonthsAgo = new Date();
    threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 4);
    expect(isStale(threeMonthsAgo.toISOString(), 3)).toBe(true);
    expect(isStale(threeMonthsAgo.toISOString(), 6)).toBe(false);
  });

  it("returns false for invalid date string", () => {
    expect(isStale("not-a-date")).toBe(false);
  });
});
