# clerk-auth-starter — operating contract (for humans and agents)

This is the standing guide to how this site is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `03-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the site without any
other source.

## What this system is

Clerk's Next.js auth starter on Cloudflare, expressed as an Orun
component-native desired-state repo. Clerk is a SaaS the site calls, not a
component here: its owner creates the Clerk application and stores its keys.

- **`apps/web`** — the site: Next.js built by `@opennextjs/cloudflare` into
  one Worker plus Static Assets. Clerk's middleware (`proxy.ts`) reads every
  request's session; `/sign-in` is Clerk's sign-in, `/dashboard` and
  `/api/protected` are protected by `auth.protect()`, and `/api/health` is
  what the deploy's smoke reads. Clerk's components load from Clerk's CDN in
  the browser. There is no database.
- **The Clerk switch** — `apps/web/lib/clerk.ts`. The build connects Clerk
  only when it has BOTH keys (`next.config.ts`); without them every page
  renders a "connect Clerk" notice where sign-in would be, `/api/protected`
  answers 503 and the proxy passes requests through.
- **`tests/web`** — the site's identity, the Clerk switch, the health and
  protected routes and the Worker-secret push (vitest), verified on the
  `dev` rung.
- **`tooling/*`** — shared TypeScript and ESLint configuration, the
  deploy-time wrangler renderer, and `wire/worker-secrets.mjs`, which hands
  Clerk's secret key to the Worker.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and test, nothing deploys.

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. `apps/web` builds once per environment, with `NEXT_PUBLIC_SITE_URL` set to
   that environment's `SITE_URL` (intent.yaml) or its workers.dev URL and
   that environment's Clerk keys when they are stored; the deploy lane then
   sets `CLERK_SECRET_KEY` on `clerk-auth-starter-web-<env>` as a Worker
   secret (`wrangler secret bulk`), `wrangler deploy` ships it, and a smoke
   test fetches `/` (rendered to its end) and `/api/health` (ok: the Worker
   holds what its build expects).
4. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
5. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "site
  converged"; probe the URLs instead.
- A change to `intent.yaml`'s `environments` (a new `SITE_URL`, say) maps to
  no component and redeploys nothing on its own. Land it with a change under
  `apps/web`.
- Storing or rotating a Clerk key builds nothing either: the keys are read
  when the site builds. Redeploy by hand after setting them.
- Cache Components are off (`next.config.ts`): on Workers a Cache
  Components render hangs. Every Clerk page renders per request.

## Secrets model

- **Brokered provider secrets**: `CLOUDFLARE_API_TOKEN` (Workers deploy
  scope) and `CLOUDFLARE_ACCOUNT_ID` — pointers minted per run from the
  workspace's Cloudflare connection. No long-lived values at rest; nothing
  to rotate by hand.
- **The owner's Clerk keys**, per environment, OPTIONAL:
  `CLERK_PUBLISHABLE_KEY` (public by design; the build inlines it into the
  pages) and `CLERK_SECRET_KEY` (the build runs without it, told only that
  it exists — `CLERK_SECRET_KEY_SET` — so no bundle or build cache holds it;
  the deploy lane hands it to the Worker as a Worker secret, the value over
  stdin).
  `apps/web/component.yaml` reads both as `optionalSecretEnv`: a key nobody
  stored is skipped, and the site builds without Clerk. Rotate one in the
  Clerk dashboard, store the new value (`orun secrets set … --env <env>`),
  redeploy.
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`. No tooling in this repository prints a secret value,
  and no document in `ai/context/` may contain one. `/api/health` reports
  whether the Worker holds `CLERK_SECRET_KEY`, never its value.

## Verifying the system

```bash
# the site on each environment (also recorded, probed, in deployment.md)
curl -s -o /dev/null -w '%{http_code}\n' https://clerk-auth-starter-web-stage.your-workers-subdomain.workers.dev/
curl -s https://clerk-auth-starter-web-prod.your-workers-subdomain.workers.dev/api/health   # {"ok":true,"clerk":"connected"|"not-connected"}

# workspace readiness (integrations + repository link)
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| connect Clerk | create an application at dashboard.clerk.com, `orun secrets set CLERK_PUBLISHABLE_KEY --env <env>` and `orun secrets set CLERK_SECRET_KEY --env <env>`, deploy by hand (README, "Connect Clerk") |
| change the site's code | `apps/web/app/` (the template's own content is `app/_template`), its name `apps/web/app/site.ts`; merge |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| serve a custom domain | attach it to the Worker in Cloudflare, set `SITE_URL` for the environment in `intent.yaml`, and replace the placeholder `clerk-auth-starter.example.com` in `intent.yaml`'s `BASE_DOMAIN` (dev, stage and prod) with it (README, "Custom domain") |
| add a runtime secret | `orun secrets set <KEY> --org <ws> --env <env>`, then an `optionalSecretEnv` entry in `apps/web/component.yaml` and a `--secret <KEY>` on its `worker-secrets.mjs` call |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `03-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 03-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Clerk owns the users, sessions and organizations; a feature that needs data
of the site's own (a profile table, say) adds a data store. Structural
changes (a second Worker, an API, a data store) follow the same
contract that deployed the site: add a component under `apps/`, `infra/` or
`packages/` with a `component.yaml`, land it as a pull request, and the
convergence run applies it.
