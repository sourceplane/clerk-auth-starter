# clerk-auth-starter — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | Next.js on Workers + Static Assets through `@opennextjs/cloudflare`, with the static-assets incremental cache | Every Clerk page renders per request; the only pre-rendered output is Next's own, and the cache serves it with no binding | `specs/epics/clerk-auth-starter/design.md` |
| 2 | Next 16.3.8, not the template's 16.4.2 | The version every OpenNext starter here is proven on; 16.3 has everything the template uses | risk CK-D |
| 3 | Cache Components off (`cacheComponents`, `partialPrefetching`, the footer's `"use cache"`) | Served by the Worker, a Cache Components render hangs until the runtime cancels it (spiked); without them the template renders per request, as it did before upstream #57 | IMPLEMENTATION-STATUS (departures) |
| 4 | Clerk connects only when the build has BOTH keys; without them the site renders a "connect Clerk" notice, `/api/protected` answers 503 and the proxy passes requests through | Clerk's provider and middleware throw on every request without keys; a fresh site must deploy and serve before its owner has a Clerk application | `apps/web/lib/clerk.ts`, `apps/web/next.config.ts` |
| 5 | The keys are Orun secrets per environment, read as `optionalSecretEnv`; the publishable key is inlined by the build, the secret key withheld from it (`env -u`, `CLERK_SECRET_KEY_SET` in its place) and handed to the Worker as a Worker secret by the deploy lane | SaaS keys are Orun secrets; the secret key must never be in a bundle, and Turbopack's cache records the build's environment (the e2e tier found it there) | `apps/web/component.yaml`, `tooling/wire/worker-secrets.mjs` |
| 6 | Clerk's UI loads from Clerk's CDN (no `ui` prop on `<ClerkProvider>`) | Bundled, `@clerk/ui` takes the Worker to 3.36 MiB gzipped, over Workers Free's 3 MiB; from the CDN it is 2.2 MiB, and the components are the same | risk CK-C |
| 7 | `/api/health` and a full-page render are the deploy's smoke | A connected build whose Worker lost its secret key fails every signed-in request; the smoke catches it at deploy, not at a visitor | `apps/web/component.yaml` |
| 8 | The template's "Deploy to Vercel" button is the site's own source link | The site deploys from its own repository; the button cloned upstream onto Vercel | IMPLEMENTATION-STATUS (departures) |
| 9 | The site's name is one seam, `SITE_NAME` in `apps/web/app/site.ts`, for the page title and the Open Graph card; `metadataBase` is `NEXT_PUBLIC_SITE_URL` | The rename rewrites one literal; the template hard-coded its Vercel origin | `apps/web/app/site.ts` |
| 10 | No custom-domain phase: a domain is the owner's step, and `SITE_URL` points the build at it; a Clerk production instance waits for that domain | The brokered `workers-deploy` token has no zone scope, and Clerk's production instances need DNS on a domain the owner holds | README, "Custom domain" |
| 11 | One landing (`01-product`) then the record (`03-docs`), each checked in the build box | A landing has a fixed cost; the convergence on main builds, deploys and smoke-tests the site for real | `docs/phases/README.md` |
| 12 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME`; no Checks workflow | A bootstrap cannot set a repository variable; a push to main must start `ci.yml` alone | `.github/workflows/ci.yml` |
| 13 | stack-tectonic 0.19.0, not 0.20.0 | 0.20.0's lane-shared install links `node_modules` out of the job's tree | portfolio-starter-kit's risk PK-J |
| 14 | Component docs are generated from the manifests and checked in CI; orun is pinned only where it runs | A hand-written copy drifts silently | `tooling/catalog/gen-component-docs.py` |
| 15 | `subdomain` is read from the Cloudflare connection, never asked; the console asks for no domain and no Clerk key | The first two belong to the account or the owner; no platform connection can mint a Clerk key | `blueprint.yaml` |
