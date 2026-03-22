import { describe, it, expect } from "vitest";

// Test TrustBadge computed logic extracted from the component

function getLabel(level: number): string {
  if (level >= 80) return "Verified";
  if (level >= 50) return "Medium";
  if (level >= 20) return "Low";
  return "Unknown";
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

function getIconClass(level: number): string {
  if (level >= 80) return "pi-verified";
  if (level >= 50) return "pi-check-circle";
  if (level >= 20) return "pi-info-circle";
  return "pi-question-circle";
}

describe("TrustBadge label", () => {
  it("returns Verified for level >= 80", () => {
    expect(getLabel(80)).toBe("Verified");
    expect(getLabel(100)).toBe("Verified");
    expect(getLabel(95)).toBe("Verified");
  });

  it("returns Medium for level 50-79", () => {
    expect(getLabel(50)).toBe("Medium");
    expect(getLabel(79)).toBe("Medium");
    expect(getLabel(65)).toBe("Medium");
  });

  it("returns Low for level 20-49", () => {
    expect(getLabel(20)).toBe("Low");
    expect(getLabel(49)).toBe("Low");
    expect(getLabel(35)).toBe("Low");
  });

  it("returns Unknown for level < 20", () => {
    expect(getLabel(0)).toBe("Unknown");
    expect(getLabel(19)).toBe("Unknown");
    expect(getLabel(10)).toBe("Unknown");
  });
});

describe("TrustBadge badgeClass", () => {
  it("returns green classes for verified", () => {
    expect(getBadgeClass(80)).toContain("green");
  });

  it("returns amber classes for medium", () => {
    expect(getBadgeClass(50)).toContain("amber");
  });

  it("returns orange classes for low", () => {
    expect(getBadgeClass(20)).toContain("orange");
  });

  it("returns neutral classes for unknown", () => {
    expect(getBadgeClass(0)).toContain("white");
  });
});

describe("TrustBadge iconClass", () => {
  it("returns pi-verified for verified level", () => {
    expect(getIconClass(80)).toBe("pi-verified");
  });

  it("returns pi-check-circle for medium level", () => {
    expect(getIconClass(50)).toBe("pi-check-circle");
  });

  it("returns pi-info-circle for low level", () => {
    expect(getIconClass(20)).toBe("pi-info-circle");
  });

  it("returns pi-question-circle for unknown level", () => {
    expect(getIconClass(0)).toBe("pi-question-circle");
  });
});
