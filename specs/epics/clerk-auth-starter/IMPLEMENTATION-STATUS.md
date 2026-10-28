# clerk-auth-starter — implementation status

| Milestone | State | Landed |
|---|---|---|
| CK0 — the spec | ✅ | the repository's first commit |
| CK1 — the auth starter on Workers | ✅ | CK-2 |
| CK2 — a baseline | planned | CK-3 |

## Departures from the upstream template

Everything not listed here is the template as it is upstream at `9e5619c`.

| # | What | Why |
|---|---|---|
| 1 | The app lives in `apps/web` of a pnpm workspace (the root lockfile, pnpm 10.12.1); `pnpm-workspace.yaml`'s `allowBuilds` and `minimumReleaseAge` are the workspace's `onlyBuiltDependencies` and a lockfile of Clerk releases older than 48 hours | One lockfile for the workspace; the composition's pnpm predates both settings (risk CK-G) |
| 2 | Next 16.3.8 and `eslint-config-next` 16.3.8, not 16.4.2; `AGENTS.md` carries 16.3.8's agent block | The Next every OpenNext starter here is proven on (risk CK-D); `next dev` rewrites the block to its own version's |
| 3 | `next.config.ts`: `output: 'standalone'`, `outputFileTracingRoot` and `turbopack.root` at the workspace root; `cacheComponents` and `partialPrefetching` off; the footer's `"use cache"` removed | OpenNext builds from the standalone output; a Cache Components render hangs in the Worker |
| 4 | `next.config.ts` `env`: `CLERK_CONNECTED` (the publishable key and the secret key — or, on a deploy, `CLERK_SECRET_KEY_SET` — at build), and the template's `.env.example` routes (`/sign-in`, `/dashboard`) as defaults | The site serves before Clerk is connected; the build never sees the secret key's value; a deploy needs only the two keys |
| 5 | `lib/clerk.ts`, `app/components/connect-clerk.tsx`; the layout, the landing's button, `/sign-in`, `/dashboard`, `/api/protected` and `proxy.ts` read the switch | Without keys Clerk throws on every request; with them each is the template's code |
| 6 | `<ClerkProvider>` without `ui={ui}`: Clerk's components load from Clerk's CDN (`@clerk/ui` stays, for its `Appearance` type) | Bundled, the Worker is over Workers Free's 3 MiB gzipped (risk CK-C) |
| 7 | `app/api/health/route.ts` | The deploy's smoke: the Worker holds the secret key its build expects |
| 8 | `app/site.ts` (`SITE_NAME`, `SOURCE_URL`, `SITE_URL`); the template's metadata reads the name and the origin (`metadataBase` was the template's vercel.app URL) | One rename seam; the origin per environment |
| 9 | The "Deploy to Vercel" button (`deploy-button.tsx`) is the site's source link (`source-button.tsx`) | The site deploys from its own repository |
| 10 | `.env.example` says the keys are Orun secrets in a deployed environment and the routes are defaults | Where each value comes from on Workers |
| 11 | `eslint.config.mjs` ignores `.open-next` and `.wrangler`; `tsconfig.json` excludes them; `typecheck` is `next typegen && tsc --noEmit`, `lint` is `eslint .` | Build output is not source; the workspace's `typecheck` / `lint` / `test` / `build` contract |
| 12 | `open-next.config.ts`, `wrangler.jsonc`, `component.yaml`, `tooling/wire/worker-secrets.mjs` | The Workers build and its deploy contract |
| 13 | `tests/web` (vitest) | The template ships none |
