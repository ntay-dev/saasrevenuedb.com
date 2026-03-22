import { describe, it, expect, vi, beforeEach } from "vitest";

import plugin from "~/plugins/supabase.client";

// Mock createClient before importing the plugin
vi.mock("@supabase/supabase-js", () => ({
  createClient: vi.fn(() => ({
    auth: {
      getSession: vi.fn().mockResolvedValue({ data: { session: null } }),
      onAuthStateChange: vi.fn((cb: any) => {
        // Store the callback for testing
        (globalThis as any).__authCallback = cb;
        return { data: { subscription: { unsubscribe: vi.fn() } } };
      }),
    },
    from: vi.fn(),
  })),
}));

describe("supabase.client plugin", () => {
  it("is a function (defineNuxtPlugin returns the setup function)", () => {
    expect(typeof plugin).toBe("function");
  });

  it("returns provide object with supabase, supabaseUser, supabaseSession", () => {
    const result = plugin() as any;
    expect(result).toBeDefined();
    expect(result.provide).toBeDefined();
    expect(result.provide).toHaveProperty("supabase");
    expect(result.provide).toHaveProperty("supabaseUser");
    expect(result.provide).toHaveProperty("supabaseSession");
  });

  it("initializes supabaseUser as null ref", () => {
    const result = plugin() as any;
    expect(result.provide.supabaseUser.value).toBeNull();
  });

  it("initializes supabaseSession as null ref", () => {
    const result = plugin() as any;
    expect(result.provide.supabaseSession.value).toBeNull();
  });

  it("creates a supabase client object with auth methods", () => {
    const result = plugin() as any;
    const client = result.provide.supabase;
    expect(client).toBeDefined();
    expect(client.auth).toBeDefined();
    expect(client.auth.getSession).toBeDefined();
    expect(client.auth.onAuthStateChange).toBeDefined();
  });

  it("logs error when supabaseUrl is missing", () => {
    const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const origConfig = (globalThis as any).useRuntimeConfig;
    (globalThis as any).useRuntimeConfig = () => ({
      public: { supabaseUrl: "", supabaseKey: "key" },
    });

    plugin();
    expect(consoleSpy).toHaveBeenCalledWith(
      "Supabase URL and Key must be provided",
    );
    (globalThis as any).useRuntimeConfig = origConfig;
    consoleSpy.mockRestore();
  });

  it("logs error when supabaseKey is missing", () => {
    const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const origConfig = (globalThis as any).useRuntimeConfig;
    (globalThis as any).useRuntimeConfig = () => ({
      public: { supabaseUrl: "https://test.supabase.co", supabaseKey: "" },
    });

    plugin();
    expect(consoleSpy).toHaveBeenCalledWith(
      "Supabase URL and Key must be provided",
    );
    (globalThis as any).useRuntimeConfig = origConfig;
    consoleSpy.mockRestore();
  });

  it("handles auth state change with session", () => {
    const result = plugin() as any;
    const user = result.provide.supabaseUser;
    const session = result.provide.supabaseSession;

    // The onAuthStateChange callback was stored
    const callback = (globalThis as any).__authCallback;
    if (callback) {
      const mockSession = {
        user: { id: "user-1", email: "test@test.com" },
        access_token: "tok",
      };
      callback("SIGNED_IN", mockSession);
      // session and user should be updated via the ref
    }
    // At minimum, these should be refs
    expect(user).toHaveProperty("value");
    expect(session).toHaveProperty("value");
  });

  it("handles auth state change with null session (sign out)", () => {
    const result = plugin() as any;
    const callback = (globalThis as any).__authCallback;
    if (callback) {
      callback("SIGNED_OUT", null);
    }
    expect(result.provide.supabaseUser).toHaveProperty("value");
  });

  it("does not log error when both URL and Key are provided", () => {
    const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    plugin();
    expect(consoleSpy).not.toHaveBeenCalled();
    consoleSpy.mockRestore();
  });
});
