// Warns at runtime if critical public config values are missing (empty strings).
// This catches cases where env vars were not set during build.
export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig();

  const checks: Record<string, string> = {
    supabaseUrl: config.public.supabaseUrl as string,
    supabaseKey: config.public.supabaseKey as string,
  };

  const missing = Object.entries(checks)
    .filter(([, value]) => !value)
    .map(([key]) => key);

  if (missing.length > 0) {
    const message = `[Config] Missing public runtime config: ${missing.join(", ")}`;
    console.warn(message);
  }
});
