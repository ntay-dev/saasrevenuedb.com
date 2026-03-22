import { defineConfig } from "vitest/config";
import { resolve } from "path";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    include: ["tests/**/*.test.ts"],
    coverage: {
      provider: "v8",
      include: [
        "app/utils/**",
        "app/stores/**",
        "app/composables/**",
        "app/plugins/**",
        "server/routes/**",
      ],
      reporter: ["text", "text-summary"],
    },
    setupFiles: ["tests/unit/setup.ts"],
  },
  resolve: {
    alias: {
      "~": resolve(__dirname, "app"),
      "~/types/database.types": resolve(
        __dirname,
        "app/types/database.types.ts",
      ),
    },
  },
});
