import { describe, it, expect } from "vitest";

// Test the trust badge classification logic (mirrors TrustBadge.vue computed)
function getLabel(level: number): string {
  if (level >= 80) return "Verified";
  if (level >= 50) return "Medium";
  if (level >= 20) return "Low";
  return "Unknown";
}

function getTooltip(level: number): string {
  if (level >= 90)
    return `Trust Level ${level}: Official company data, SEC filings`;
  if (level >= 80)
    return `Trust Level ${level}: Stripe-verified, Crunchbase, PitchBook`;
  if (level >= 70) return `Trust Level ${level}: LinkedIn, Wikipedia, G2`;
  if (level >= 50) return `Trust Level ${level}: News articles, press releases`;
  if (level >= 20) return `Trust Level ${level}: Community data, estimates`;
  return `Trust Level ${level}: Unverified data`;
}

function getBadgeClass(level: number): string {
  if (level >= 80)
    return "bg-green-500/10 text-green-400 ring-1 ring-green-500/20";
  if (level >= 50)
    return "bg-amber-500/10 text-amber-400 ring-1 ring-amber-500/20";
  if (level >= 20)
    return "bg-orange-500/10 text-orange-400 ring-1 ring-orange-500/20";
  return "bg-white/5 text-(--color-text-muted) ring-1 ring-white/10";
}

describe("trust badge enhanced", () => {
  describe("labels", () => {
    it("returns Verified for 80+", () => {
      expect(getLabel(100)).toBe("Verified");
      expect(getLabel(80)).toBe("Verified");
      expect(getLabel(90)).toBe("Verified");
    });

    it("returns Medium for 50-79", () => {
      expect(getLabel(50)).toBe("Medium");
      expect(getLabel(79)).toBe("Medium");
      expect(getLabel(65)).toBe("Medium");
    });

    it("returns Low for 20-49", () => {
      expect(getLabel(20)).toBe("Low");
      expect(getLabel(49)).toBe("Low");
      expect(getLabel(35)).toBe("Low");
    });

    it("returns Unknown for 0-19", () => {
      expect(getLabel(0)).toBe("Unknown");
      expect(getLabel(19)).toBe("Unknown");
      expect(getLabel(10)).toBe("Unknown");
    });
  });

  describe("tooltips", () => {
    it("shows SEC filings for 90+", () => {
      expect(getTooltip(95)).toContain("Official company data");
      expect(getTooltip(95)).toContain("SEC filings");
    });

    it("shows Stripe-verified for 80-89", () => {
      expect(getTooltip(85)).toContain("Stripe-verified");
    });

    it("shows LinkedIn/Wikipedia for 70-79", () => {
      expect(getTooltip(75)).toContain("LinkedIn");
      expect(getTooltip(75)).toContain("Wikipedia");
    });

    it("shows news/press for 50-69", () => {
      expect(getTooltip(60)).toContain("News articles");
    });

    it("shows community data for 20-49", () => {
      expect(getTooltip(30)).toContain("Community data");
    });

    it("shows unverified for <20", () => {
      expect(getTooltip(10)).toContain("Unverified");
    });

    it("includes the actual level number", () => {
      expect(getTooltip(85)).toContain("85");
      expect(getTooltip(42)).toContain("42");
    });
  });

  describe("badge classes", () => {
    it("uses green for verified", () => {
      expect(getBadgeClass(85)).toContain("green");
    });

    it("uses amber for medium", () => {
      expect(getBadgeClass(65)).toContain("amber");
    });

    it("uses orange for low", () => {
      expect(getBadgeClass(35)).toContain("orange");
    });

    it("uses neutral for unknown", () => {
      expect(getBadgeClass(5)).toContain("white");
    });
  });
});
