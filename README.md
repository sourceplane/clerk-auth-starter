# clerk-auth-starter

Clerk's [Next.js auth starter](https://github.com/clerk/nextjs-auth-starter-template)
(Vercel's "Clerk Authentication Starter" template) — sign-in and sign-up with
Clerk's prebuilt components, Clerk's middleware, a protected dashboard
showing the signed-in user, their session and their organization, and a
protected API route — running on **Cloudflare Workers + Static Assets**
through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare), and
packaged as an **Orun baseline**: one command takes a new site from nothing
to live on stage and prod, in its own repository, under its own name.

The template's code is the code. What the port adds is the Workers build,
the monorepo wrapper, a test package and the deploy contract; what it
changes is what Workers and a fresh, unattended deployment force: Clerk's
two keys are Orun secrets the owner stores after the build (the publishable
key inlined by the build, the secret key handed to the Worker as a Worker
secret), the site renders a "connect Clerk" notice until both are there,
Cache Components are off (a Cache Components render hangs in the Worker),
Clerk's components load from Clerk's CDN rather than being bundled (bundled,
the Worker is over Workers Free's 3 MiB), and the "Deploy to Vercel" button
is the site's own source link. What the baseline adds is everything needed
to make a copy of it somebody else's — built the way
[cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) is. See
[`specs/epics/clerk-auth-starter`](specs/epics/clerk-auth-starter/README.md)
for the design, the milestones and the as-built status, including every
departure.

## Instantiating a site

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/clerk-auth-starter
cd clerk-auth-starter
orun new --blueprint repo-blueprint.yaml --out ~/sites/acme-notes --run-hooks --resume \
  --set reponame=acme-notes --set productname="Acme Notes" \
  --set githuborg=acme-inc --set subdomain=<workers-dev-subdomain>
```

Or, once the platform's registry lists it, from the Orun console (Baselines →
`clerk-auth-starter` → Build). Two phases — `01-product` (the repository
created, then the whole site in one pull request, deployed to stage and prod
and smoke-tested) and `03-docs` (the live deployment recorded) — each landing
one pull request in the new repository.
**[BOOTSTRAP.md](BOOTSTRAP.md)** is the operator guide;
[docs/phases/](docs/phases/README.md) has a page per phase.

The new repository receives the **site only** — the app, its tests, its CI,
its tooling, a README and an `AGENTS.md` of its own and its operating
contract — renamed throughout to the site's name, repository and Cloudflare
Worker. None of this repository's machinery ships. **Clerk is the owner's to
connect afterwards** (the site's README, "Connect Clerk"): no platform
brokers it, so the card asks for no Clerk key, and the site goes live with a
"connect Clerk" notice where sign-in would be.

| What makes it a baseline | Where |
|---|---|
| The console card (inputs, secrets, programme) | `blueprint.yaml` |
| The build document (modules, phases, hooks) | `repo-blueprint.yaml` |
| This tree's identity, and the bootstrap's task contracts | `.baseline/` |
| The rename engine (product-name seam: `apps/web/app/site.ts`) | `tooling/rebrand/rebrand.mjs` |
| The bootstrap's helpers (deferrals, redeploy marker, work-tree strip) | `tooling/bootstrap/` |
| The deployment-record renderer | `hooks/render-deployment-docs.sh` |
| The site's README, agent page and context pack | `.baseline/product/README.md`, `.baseline/product/AGENTS.md`, `ai/context/` |
| The baseline's tests: contract, leak, offline bootstrap, end to end | `testing/`, `.github/workflows/baseline.yml` |
| Cutting a `baseline-vN` tag | `.github/workflows/tag.yml` |

## What is here (the site)

| Surface | Where |
|---|---|
| The site's name, source link and origin | `apps/web/app/site.ts` |
| Whether Clerk is connected, and the notice until it is | `apps/web/lib/clerk.ts`, `apps/web/next.config.ts`, `apps/web/app/components/connect-clerk.tsx` |
| Home, `/sign-in`, `/dashboard` (the template's own content in `app/_template`) | `apps/web/app` |
| Clerk's middleware | `apps/web/proxy.ts` |
| `/api/protected` (Clerk-protected), `/api/health` (the deploy's smoke) | `apps/web/app/api` |
| The Worker-secret push (Clerk's secret key) | `tooling/wire/worker-secrets.mjs` |
| Workers build and deploy contract | `apps/web/next.config.ts`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| Tests | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build            # next build + opennextjs-cloudflare build → apps/web/.open-next
```

The build needs no Clerk application: without its keys the site is the
"connect Clerk" site. With a development instance's keys in
`apps/web/.env.local` (`apps/web/.env.example`), `pnpm --filter @app/web dev`
is the template as Clerk ships it.

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Next.js hosting, `proxy.ts` (Clerk's middleware) on Vercel's runtime | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets; the proxy runs in the Worker (OpenNext's Node.js middleware) |
| The Clerk integration setting `CLERK_SECRET_KEY` and `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` as project env vars | Orun secrets per environment the owner stores (`CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`), read by the build as optional refs; the publishable key inlined, the secret key a Worker secret every deploy sets |
| Clerk's keyless mode / missing keys (an error page in production) | The "connect Clerk" site: every page renders, sign-in is a notice, `/api/protected` 503, the proxy a pass-through — until both keys are stored |
| `.env` routes (`NEXT_PUBLIC_CLERK_SIGN_IN_URL`, the redirect URLs) | The same values as build defaults in `next.config.ts` |
| Cache Components (`cacheComponents`, `partialPrefetching`, `"use cache"`) | Off: every Clerk page renders per request in the Worker |
| `@clerk/ui` bundled through `<ClerkProvider ui={ui}>` | Clerk's components from Clerk's CDN, Clerk's default |
| Hard-coded `vercel.app` `metadataBase` | `NEXT_PUBLIC_SITE_URL`, set per environment by the deploy |
| "Deploy to Vercel" button (clone the template) | The site's own source link; `orun new --blueprint repo-blueprint.yaml` is the clone — a new repository, branded, deployed |
| Deploy on push | Orun deploys `<repo>-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`), smoke-tested |

## CI

| Workflow | What it runs | Ships to a site |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a site carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the site built and dry-deployed per environment; the tests' `quick-check` lane installs and checks the package, it does not run them), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
| `baseline.yml` | the baseline's own tiers: contract tests, the blueprint read by the pinned orun, the leak gate, the offline bootstrap, the site built, dry-deployed and served — without Clerk, and with made-up Clerk keys (the secret key in no file of the build, Clerk's middleware answering signed-out requests) | no |
| `tag.yml` | cuts a `baseline-vN` tag (manual) | no |
