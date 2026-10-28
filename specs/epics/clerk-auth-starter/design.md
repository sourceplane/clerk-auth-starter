# clerk-auth-starter — design

## The template

[clerk/nextjs-auth-starter-template](https://github.com/clerk/nextjs-auth-starter-template)
(Next.js 16.4 App Router, `@clerk/nextjs` 7 — Clerk's Core 3 — `@clerk/ui`,
Tailwind CSS 4) is Clerk's starter for authentication on Next.js: a landing
page whose button is Clerk's `<SignInButton>` (or a link to the dashboard
when signed in), `/sign-in` with Clerk's `<SignIn>`, `/dashboard` behind
`auth.protect()` showing the signed-in user, session and organization (and
the raw objects, highlighted), a protected API route (`/api/protected`), and
Clerk's middleware in `proxy.ts`. Its keys are `CLERK_SECRET_KEY` and
`NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, set on Vercel by the Clerk integration;
its routes are the `NEXT_PUBLIC_CLERK_*` URLs in its `.env.example`. Its
template content is `app/_template`, built to be removed.

## How it maps to Cloudflare

| Vercel | Here | Why |
|---|---|---|
| Next.js hosting | One Worker built by `@opennextjs/cloudflare` (`output: 'standalone'`), the static-assets incremental cache | Clerk pages render per request; the cache needs no binding |
| `proxy.ts` (Clerk's middleware) | In the Worker: OpenNext bundles Next 16's Node.js middleware | The same file; OpenNext calls the shape experimental on Cloudflare (risk CK-E) |
| The Clerk integration's env vars | `CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY`, Orun secrets per environment, read by the build as `optionalSecretEnv` | SaaS keys are Orun secrets; no platform connection mints a Clerk key |
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` read at build | Inlined by `next build`, as upstream | It is public by design |
| `CLERK_SECRET_KEY` read at request time | A Worker secret the deploy lane sets (`tooling/wire/worker-secrets.mjs`, `wrangler secret bulk` over stdin) before `wrangler deploy`; `next build` runs without it, told only that it exists (`CLERK_SECRET_KEY_SET`) | The Worker reads it from its env; no bundle may hold it, nor the bundler's cache, which records the build's environment |
| Cache Components | Off | Served by the Worker, a Cache Components render hangs until workerd cancels it (spiked, 2026-10-28) |
| `@clerk/ui` bundled (`ui={ui}`) | Clerk's components from Clerk's CDN (Clerk's default) | Bundled, the Worker is 3.36 MiB gzipped, over Workers Free's 3 MiB; from the CDN, 2.2 MiB |
| `metadataBase` (vercel.app) | `NEXT_PUBLIC_SITE_URL` per environment | The Open Graph image's URL is absolute |
| "Deploy to Vercel" button | The site's own source link | The site deploys from its own repository |

## The site before Clerk is connected

A bootstrap has no Clerk application to give the site, and Clerk's provider
and middleware throw "Clerk keys are missing" on every request without one.
So the build decides once, in `next.config.ts`: Clerk is connected when the
build has **both** keys, and the answer is inlined as `CLERK_CONNECTED`,
read by `lib/clerk.ts`. Not connected, the layout renders no
`<ClerkProvider>`, the landing's button is "Connect Clerk to sign in",
`/sign-in` and `/dashboard` are a notice that says what to store and where,
`/api/protected` answers 503, and the proxy passes requests through.
Connected, every one of those is the template's own code, unchanged. One key
without the other builds the unconnected site: a site that fails on its
first request is worse than one that says what is missing.

`/api/health` reports `{"ok", "clerk"}`: ok unless the build connected Clerk
and the Worker lacks `CLERK_SECRET_KEY` — which the deploy's smoke reads, so
a Worker that lost its secret fails its deploy.

## The repository

portfolio-starter-kit's shape: `apps/web` (type
`cloudflare-workers-assets-turbo`, lane `isolated`) and `tests/web` (type
`turbo-package`, a vitest suite run on the `dev` rung). No infrastructure:
Clerk holds the users, sessions and organizations. The site's name is one
seam, `SITE_NAME` in `apps/web/app/site.ts` (the page title and the Open
Graph card); `SOURCE_URL` is the header's source link, rewritten to the
site's repository.

## The build

`next build` (Turbopack, the template's Tailwind loader), then
`opennextjs-cloudflare build --skipBuild` and `populateCache local`, then —
in a deploy lane, with the environment's secret key — the Worker-secret
push. `repo-blueprint.yaml` is portfolio-starter-kit's: one landing
(`01-product`) places, brands and lands the whole tree, one convergence
builds and deploys stage and prod side by side, and `03-docs` records what
went live. The smoke checks the home page renders to its end and
`/api/health` is ok.

## Out of scope

- A Clerk application per site, made by the bootstrap: Clerk has no
  connection here, and its Platform API is not a composition.
- Webhooks (Clerk → the site): the template has none.

## The alternative rejected

**Clerk's keyless mode for the unconnected site.** `@clerk/nextjs` creates a
temporary application when `next dev` runs without keys; in a production
build it does not, and the keys it creates belong to whoever claims them. A
deployed site needs keys its owner holds, so the unconnected site says so
instead.
