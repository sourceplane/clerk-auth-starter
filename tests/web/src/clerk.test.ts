import { afterEach, describe, expect, it, vi } from "vitest";

// The switch every Clerk surface reads (apps/web/lib/clerk.ts), and the build
// decision that sets it (apps/web/next.config.ts): Clerk is connected only
// when the build has BOTH keys. The values here are made up; no real key is
// ever in this repository.
const PUBLISHABLE = "pk_test_ZmFrZS1hcHAtMDAuY2xlcmsuYWNjb3VudHMuZGV2JA==";
const SECRET = "sk_test_offline_fixture_not_a_key";

const KEYS = ["CLERK_CONNECTED", "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY", "CLERK_SECRET_KEY", "CLERK_SECRET_KEY_SET"] as const;

afterEach(() => {
  for (const k of KEYS) delete process.env[k];
  vi.resetModules();
});

async function buildEnv(env: Partial<Record<(typeof KEYS)[number], string>>) {
  Object.assign(process.env, env);
  const { default: config } = await import("../../../apps/web/next.config");
  return config.env ?? {};
}

describe("the Clerk switch (apps/web/lib/clerk.ts)", () => {
  it("is off unless the build said connected", async () => {
    expect((await import("../../../apps/web/lib/clerk")).clerkConnected).toBe(false);
    vi.resetModules();
    process.env.CLERK_CONNECTED = "true";
    expect((await import("../../../apps/web/lib/clerk")).clerkConnected).toBe(true);
  });
});

describe("the build's decision (apps/web/next.config.ts)", () => {
  it("connects Clerk with both keys", async () => {
    const env = await buildEnv({ NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: PUBLISHABLE, CLERK_SECRET_KEY: SECRET });
    expect(env.CLERK_CONNECTED).toBe("true");
  });

  it("connects Clerk on a deploy, told only that the secret key exists", async () => {
    const env = await buildEnv({ NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: PUBLISHABLE, CLERK_SECRET_KEY_SET: "true" });
    expect(env.CLERK_CONNECTED).toBe("true");
  });

  it("does not with one key, or none", async () => {
    expect((await buildEnv({})).CLERK_CONNECTED).toBe("");
    vi.resetModules();
    expect((await buildEnv({ NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: PUBLISHABLE })).CLERK_CONNECTED).toBe("");
    for (const k of KEYS) delete process.env[k];
    vi.resetModules();
    expect((await buildEnv({ CLERK_SECRET_KEY: SECRET })).CLERK_CONNECTED).toBe("");
    for (const k of KEYS) delete process.env[k];
    vi.resetModules();
    // `${CLERK_SECRET_KEY:+true}` with no key is empty: not connected.
    expect((await buildEnv({ NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: PUBLISHABLE, CLERK_SECRET_KEY_SET: "" })).CLERK_CONNECTED).toBe("");
  });

  it("never puts the secret key in the build's inlined env", async () => {
    const env = await buildEnv({ NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: PUBLISHABLE, CLERK_SECRET_KEY: SECRET });
    expect(Object.keys(env)).not.toContain("CLERK_SECRET_KEY");
    expect(Object.values(env)).not.toContain(SECRET);
  });

  it("routes Clerk to the template's pages by default", async () => {
    const env = await buildEnv({});
    expect(env.NEXT_PUBLIC_CLERK_SIGN_IN_URL).toBe("/sign-in");
    expect(env.NEXT_PUBLIC_CLERK_SIGN_IN_FORCE_REDIRECT_URL).toBe("/dashboard");
    expect(env.NEXT_PUBLIC_CLERK_SIGN_UP_FORCE_REDIRECT_URL).toBe("/dashboard");
  });
});

describe("/api/health (apps/web/app/api/health/route.ts)", () => {
  async function health(env: Partial<Record<(typeof KEYS)[number], string>>) {
    Object.assign(process.env, env);
    const { GET } = await import("app/api/health/route");
    const res = GET();
    return { status: res.status, body: await res.json() };
  }

  it("is ok with no Clerk at all", async () => {
    expect(await health({})).toEqual({ status: 200, body: { ok: true, clerk: "not-connected" } });
  });

  it("is ok when connected and the Worker holds the secret key", async () => {
    expect(await health({ CLERK_CONNECTED: "true", CLERK_SECRET_KEY: SECRET })).toEqual({
      status: 200,
      body: { ok: true, clerk: "connected" },
    });
  });

  it("fails when connected but the Worker lacks the secret key, and names no value", async () => {
    const res = await health({ CLERK_CONNECTED: "true" });
    expect(res).toEqual({ status: 503, body: { ok: false, clerk: "connected" } });
  });
});

describe("/api/protected until Clerk is connected (apps/web/app/api/protected/route.ts)", () => {
  it("answers 503, saying why", async () => {
    const { GET, POST } = await import("app/api/protected/route");
    for (const handler of [GET, POST]) {
      const res = await handler();
      expect(res.status).toBe(503);
      expect(await res.json()).toEqual({ error: "Clerk is not connected" });
    }
  });
});
