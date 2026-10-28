import type { NextConfig } from "next";
import path from "node:path";

// Clerk is connected when the build has BOTH keys: the publishable key, which
// `next build` inlines into the pages, and the secret key, which the deploy
// hands to the Worker as a Worker secret (tooling/wire/worker-secrets.mjs) and
// which no bundle ever contains. One without the other would build a site
// that fails on its first request, so it builds the "connect Clerk" site
// instead (lib/clerk.ts).
//
// What the build needs of the secret key is that it EXISTS. A deploy builds
// with CLERK_SECRET_KEY_SET and without the key itself (component.yaml's
// buildCommand), so neither the bundles nor the bundler's own cache
// (`.next/cache`, which holds the build's environment) ever see its value; a
// local build reads the key from `.env.local`.
const hasSecretKey =
  Boolean(process.env.CLERK_SECRET_KEY) || process.env.CLERK_SECRET_KEY_SET === "true";
const connected = Boolean(process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY) && hasSecretKey;

const nextConfig: NextConfig = {
  env: {
    CLERK_CONNECTED: connected ? "true" : "",
    // The template's routes for Clerk (its .env.example's values), so a
    // deploy needs nothing set but the two keys. A build environment that
    // sets one of these wins.
    NEXT_PUBLIC_CLERK_SIGN_IN_URL: process.env.NEXT_PUBLIC_CLERK_SIGN_IN_URL || "/sign-in",
    NEXT_PUBLIC_CLERK_SIGN_IN_FORCE_REDIRECT_URL:
      process.env.NEXT_PUBLIC_CLERK_SIGN_IN_FORCE_REDIRECT_URL || "/dashboard",
    NEXT_PUBLIC_CLERK_SIGN_UP_FORCE_REDIRECT_URL:
      process.env.NEXT_PUBLIC_CLERK_SIGN_UP_FORCE_REDIRECT_URL || "/dashboard",
  },
  turbopack: {
    // The workspace root: Next resolves `next` and the app's dependencies
    // from the monorepo's node_modules.
    root: path.join(__dirname, "../.."),
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
  // Required by @opennextjs/cloudflare, which bundles `.next/standalone/**`
  // into the Worker. Trace from the monorepo root so workspace dependencies
  // resolve from the root node_modules.
  output: "standalone",
  outputFileTracingRoot: path.join(__dirname, "../.."),
};

export default nextConfig;
