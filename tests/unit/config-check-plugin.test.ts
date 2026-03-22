import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

import plugin from "~/plugins/config-check.client";

describe("config-check.client plugin", () => {
  let origConfig: any;

  beforeEach(() => {
    origConfig = (globalThis as any).useRuntimeConfig;
  });

  afterEach(() => {
    (globalThis as any).useRuntimeConfig = origConfig;
  });

  it("is a function", () => {
    expect(typeof plugin).toBe("function");
  });

  it("does not warn when all config values are present", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    (globalThis as any).useRuntimeConfig = () => ({
      public: {
        supabaseUrl: "https://test.supabase.co",
        supabaseKey: "test-anon-key",
      },
    });

    plugin();
    expect(warnSpy).not.toHaveBeenCalled();
    warnSpy.mockRestore();
  });

  it("warns when supabaseUrl is missing", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    (globalThis as any).useRuntimeConfig = () => ({
      public: { supabaseUrl: "", supabaseKey: "test-anon-key" },
    });

    plugin();
    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(warnSpy.mock.calls[0][0]).toContain("supabaseUrl");
    warnSpy.mockRestore();
  });

  it("warns when supabaseKey is missing", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    (globalThis as any).useRuntimeConfig = () => ({
      public: { supabaseUrl: "https://test.supabase.co", supabaseKey: "" },
    });

    plugin();
    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(warnSpy.mock.calls[0][0]).toContain("supabaseKey");
    warnSpy.mockRestore();
  });

  it("warns with both keys when both are missing", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    (globalThis as any).useRuntimeConfig = () => ({
      public: { supabaseUrl: "", supabaseKey: "" },
    });

    plugin();
    expect(warnSpy).toHaveBeenCalledTimes(1);
    const msg = warnSpy.mock.calls[0][0] as string;
    expect(msg).toContain("supabaseUrl");
    expect(msg).toContain("supabaseKey");
    warnSpy.mockRestore();
  });

  it("includes [Config] prefix in warning message", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    (globalThis as any).useRuntimeConfig = () => ({
      public: { supabaseUrl: "", supabaseKey: "" },
    });

    plugin();
    expect(warnSpy.mock.calls[0][0]).toContain("[Config]");
    warnSpy.mockRestore();
  });
});
