import { afterEach, describe, expect, it, vi } from "vitest";

describe("site identity (apps/web/app/site.ts)", () => {
  afterEach(() => {
    delete process.env.NEXT_PUBLIC_SITE_URL;
    vi.resetModules();
  });

  it("names the site and links its source repository", async () => {
    const { SITE_NAME, SOURCE_URL } = await import("app/site");
    expect(SITE_NAME.trim()).not.toBe("");
    expect(SOURCE_URL).toMatch(/^https:\/\/github\.com\/[A-Za-z0-9-]+\/[a-z0-9-]+$/);
  });

  it("takes its origin from NEXT_PUBLIC_SITE_URL, else localhost", async () => {
    expect((await import("app/site")).SITE_URL).toBe("http://localhost:3000");
    vi.resetModules();
    process.env.NEXT_PUBLIC_SITE_URL = "https://auth.example.com";
    expect((await import("app/site")).SITE_URL).toBe("https://auth.example.com");
  });

  it("titles every page with the site's name", async () => {
    const { SITE_NAME } = await import("app/site");
    const { templateMetadata, defaultMetadata } = await import("app/_template/content/metadata");
    expect(templateMetadata.title).toBe(SITE_NAME);
    expect(defaultMetadata.title).toBe(SITE_NAME);
    expect(String(templateMetadata.metadataBase)).toBe("http://localhost:3000/");
  });
});
