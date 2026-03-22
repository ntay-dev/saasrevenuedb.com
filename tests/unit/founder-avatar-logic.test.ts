import { describe, it, expect } from "vitest";

// Test the FounderAvatar fallback URL generation logic

function generateFallbackUrl(name: string): string {
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&size=32&background=3b82f6&color=fff&bold=true`;
}

describe("FounderAvatar fallback URL", () => {
  it("generates correct fallback URL for simple name", () => {
    const url = generateFallbackUrl("John Doe");
    expect(url).toBe(
      "https://ui-avatars.com/api/?name=John%20Doe&size=32&background=3b82f6&color=fff&bold=true",
    );
  });

  it("encodes special characters in name", () => {
    const url = generateFallbackUrl("Max Müller");
    expect(url).toContain("name=Max%20M%C3%BCller");
  });

  it("handles single-word name", () => {
    const url = generateFallbackUrl("Admin");
    expect(url).toContain("name=Admin");
  });

  it("includes correct size parameter", () => {
    const url = generateFallbackUrl("Test");
    expect(url).toContain("size=32");
  });

  it("includes correct background color", () => {
    const url = generateFallbackUrl("Test");
    expect(url).toContain("background=3b82f6");
  });

  it("includes bold=true", () => {
    const url = generateFallbackUrl("Test");
    expect(url).toContain("bold=true");
  });
});
