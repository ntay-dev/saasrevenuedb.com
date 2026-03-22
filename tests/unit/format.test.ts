import { describe, it, expect } from "vitest";
import {
  formatCurrency,
  formatCompact,
  formatNumber,
  formatPercent,
  formatDate,
  formatDateShort,
} from "~/utils/format";

describe("formatCurrency", () => {
  it("formats a number as USD currency", () => {
    expect(formatCurrency(1000)).toBe("$1,000");
  });

  it("formats large numbers", () => {
    expect(formatCurrency(1_234_567)).toBe("$1,234,567");
  });

  it("formats zero", () => {
    expect(formatCurrency(0)).toBe("$0");
  });

  it("returns dash for null", () => {
    expect(formatCurrency(null)).toBe("\u2014");
  });

  it("returns dash for undefined", () => {
    expect(formatCurrency(undefined)).toBe("\u2014");
  });

  it("accepts a different currency", () => {
    const result = formatCurrency(1000, "EUR");
    expect(result).toContain("1,000");
    // EUR symbol varies by locale implementation
  });

  it("formats negative values", () => {
    const result = formatCurrency(-500);
    expect(result).toContain("500");
  });
});

describe("formatCompact", () => {
  it("formats thousands as K", () => {
    expect(formatCompact(1500)).toBe("1.5K");
  });

  it("formats millions as M", () => {
    expect(formatCompact(2_500_000)).toBe("2.5M");
  });

  it("formats small numbers as-is", () => {
    expect(formatCompact(42)).toBe("42");
  });

  it("returns dash for null", () => {
    expect(formatCompact(null)).toBe("\u2014");
  });

  it("returns dash for undefined", () => {
    expect(formatCompact(undefined)).toBe("\u2014");
  });

  it("formats zero", () => {
    expect(formatCompact(0)).toBe("0");
  });

  it("formats billions", () => {
    expect(formatCompact(1_000_000_000)).toBe("1B");
  });
});

describe("formatNumber", () => {
  it("formats with en-US locale by default", () => {
    const result = formatNumber(1234);
    // en-US uses commas as thousand separators
    expect(result).toBe("1,234");
  });

  it("returns dash for null", () => {
    expect(formatNumber(null)).toBe("\u2014");
  });

  it("returns dash for undefined", () => {
    expect(formatNumber(undefined)).toBe("\u2014");
  });

  it("formats zero", () => {
    expect(formatNumber(0)).toBe("0");
  });

  it("accepts a custom locale", () => {
    const result = formatNumber(1234, "en-US");
    expect(result).toBe("1,234");
  });
});

describe("formatPercent", () => {
  it("formats positive values with + sign", () => {
    expect(formatPercent(15)).toBe("+15%");
  });

  it("formats negative values with - sign", () => {
    expect(formatPercent(-5)).toBe("-5%");
  });

  it("formats zero with + sign", () => {
    expect(formatPercent(0)).toBe("+0%");
  });

  it("returns dash for null", () => {
    expect(formatPercent(null)).toBe("\u2014");
  });

  it("returns dash for undefined", () => {
    expect(formatPercent(undefined)).toBe("\u2014");
  });

  it("handles decimal percentages", () => {
    expect(formatPercent(3.5)).toBe("+3.5%");
  });
});

describe("formatDate", () => {
  it("formats a date string in en-US locale", () => {
    const result = formatDate("2024-01-15");
    expect(result).toBe("Jan 15, 2024");
  });

  it("returns dash for null", () => {
    expect(formatDate(null)).toBe("\u2014");
  });

  it("returns dash for undefined", () => {
    expect(formatDate(undefined)).toBe("\u2014");
  });

  it("returns dash for empty string", () => {
    expect(formatDate("")).toBe("\u2014");
  });

  it("formats another date", () => {
    const result = formatDate("2023-06-20");
    expect(result).toBe("Jun 20, 2023");
  });
});

describe("formatDateShort", () => {
  it("formats a date string as short month + year", () => {
    const result = formatDateShort("2024-01-15");
    expect(result).toBe("Jan 2024");
  });

  it("returns dash for null", () => {
    expect(formatDateShort(null)).toBe("\u2014");
  });

  it("returns dash for undefined", () => {
    expect(formatDateShort(undefined)).toBe("\u2014");
  });

  it("returns dash for empty string", () => {
    expect(formatDateShort("")).toBe("\u2014");
  });

  it("formats summer month", () => {
    const result = formatDateShort("2023-06-01");
    expect(result).toBe("Jun 2023");
  });
});
