# clerk-auth-starter

Authentication and user management by [Clerk](https://clerk.com) — sign-in
and sign-up with Clerk's prebuilt components, Clerk's middleware, a protected
dashboard showing the signed-in user, their session and their organization,
and a protected API route — as a Next.js app on **Cloudflare Workers +
Static Assets** through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare).

Working on it with a coding agent? [AGENTS.md](AGENTS.md) says what to read
first, how a change lands and what not to touch.

## Live deployment

<!-- 03-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the site uses into
[ai/context/deployment.md](ai/context/deployment.md); how the site deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 03-docs:end -->

## Connect Clerk

The site deploys and serves before it has a Clerk application: until its
build is given an application's two keys, every page renders with a
**"connect Clerk"** notice where sign-in would be, and `/api/health` reports
`"clerk":"not-connected"`. To turn sign-in on:

1. **Create an application** in the [Clerk dashboard](https://dashboard.clerk.com)
   and pick the sign-in methods you want. Its **development** instance works
   on the site's workers.dev URLs as they are. A Clerk **production**
   instance needs a domain of your own (Clerk asks for DNS records on it), so
   set up the custom domain below first and use the production keys there.
   For the dashboard's organization panel, turn on Organizations
   (Configure → Organizations).
2. **Give the site its keys**, once per deployed environment: the
   **publishable key** (`pk_…`) and the **secret key** (`sk_…`) from
   Configure → API keys. They are this repository's Orun secrets, and stage
   and prod can each name their own application or instance:

   ```bash
   orun secrets set CLERK_PUBLISHABLE_KEY --env stage   # prompts for the value
   orun secrets set CLERK_SECRET_KEY      --env stage
   orun secrets set CLERK_PUBLISHABLE_KEY --env prod
   orun secrets set CLERK_SECRET_KEY      --env prod
   ```

   The build inlines the publishable key into the pages; the secret key it
   never sees (it is told only that one exists), and the deploy hands it to
   the Worker as a Worker secret (`wrangler secret bulk`), so it is in no
   bundle, no build cache and no log. The site connects only when the
   build has **both**: one without the other builds the "connect Clerk" site
   again rather than one that fails on its first request.
3. **Redeploy the site**: a secret is read when the site builds, and setting
   one builds nothing. Use **Deploy by hand** below, or change the stamp on
   the last line of `apps/web/component.yaml` (`# orun: redeploy …`) and
   merge. From that deploy on, the home page's button is Clerk's **Sign in**,
   `/dashboard` sends a signed-out visitor to `/sign-in`, and `/api/health`
   reports `"clerk":"connected"` — and the deploy's smoke test fails if the
   Worker ever lacks the secret key its build expects.

To run it locally, copy `apps/web/.env.example` to `apps/web/.env.local` and
fill in the two keys (a development instance's); `wrangler dev`
(`pnpm --filter @app/web preview`) reads the secret key from
`apps/web/.dev.vars` instead. Neither file is ever committed.

## What is here

| Surface | Where |
|---|---|
| The site's name and source link | `apps/web/app/site.ts` |
| Whether Clerk is connected, and the notice until it is | `apps/web/lib/clerk.ts`, `apps/web/app/components/connect-clerk.tsx`, `apps/web/next.config.ts` |
| Home, `/sign-in`, `/dashboard` | `apps/web/app` (the template's own content in `app/_template`, built to be removed when you make the app yours) |
| Clerk's middleware | `apps/web/proxy.ts` |
| `/api/protected` (Clerk-protected), `/api/health` (the deploy's smoke) | `apps/web/app/api` |
| The Worker-secret push | `tooling/wire/worker-secrets.mjs` |
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

```bash
pnpm --filter @app/web dev        # http://localhost:3000
pnpm --filter @app/web preview    # wrangler dev over the built Worker
```

Build-time variables (`apps/web/.env.example`):

| Variable | What it does |
|---|---|
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY` | The Clerk application's keys (above). Both, or the site builds without Clerk. |
| `NEXT_PUBLIC_CLERK_SIGN_IN_URL`, `NEXT_PUBLIC_CLERK_SIGN_IN_FORCE_REDIRECT_URL`, `NEXT_PUBLIC_CLERK_SIGN_UP_FORCE_REDIRECT_URL` | Where Clerk sends people. Default `/sign-in`, `/dashboard`, `/dashboard` (`apps/web/next.config.ts`). |
| `NEXT_PUBLIC_SITE_URL` | The site's public origin, for the Open Graph image's absolute URL. The deploy sets it per environment (see below). Defaults to `http://localhost:3000`. |

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. The site deploys to `stage`, then to
`prod` once stage has converged on the same commit; `dev` only verifies. The
Worker is `clerk-auth-starter-web-<env>` on your account's workers.dev
subdomain, and every deploy is smoke-tested over HTTP: the home page renders
to its end, and `/api/health` answers ok. A pull request runs the same
pipeline's verify lanes: the site built and dry-deployed for each
environment, with nothing deployed. They do not lint or run the tests, so
run `pnpm typecheck`, `pnpm lint` and `pnpm test` before you push. (A push
to `main` builds, deploys and smoke-tests.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection, and Clerk's keys are Orun secrets; nothing
provider-shaped is stored in the repository or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after storing or
rotating Clerk's keys, say. A component with nothing to run in that
environment (a test suite in `prod`) is left out with a notice.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain:

1. Add the domain to the Cloudflare account the site deploys into, and attach
   it to the Worker (dashboard → Workers & Pages →
   `clerk-auth-starter-web-prod` → Settings → Domains & Routes → Add →
   Custom domain). Do the same for stage with a subdomain if you want one.
2. Set the environment's public origin in `intent.yaml`, so the Open Graph
   image's URL uses it (until then it uses the workers.dev URL):

   ```yaml
   environments:
     prod:
       env:
         SITE_URL: https://clerk-auth-starter.example.com
   ```

   The site was born with the reserved placeholder
   `clerk-auth-starter.example.com` where its domain goes: that example,
   and `BASE_DOMAIN` under each environment (dev, stage and prod) in
   `intent.yaml`. Replace it with your domain in the same change.

3. For a Clerk **production** instance, add the same domain to it in the
   Clerk dashboard (Configure → Domains) and create the DNS records it asks
   for in Cloudflare, then store that instance's keys for the environment
   (Connect Clerk, step 2).
4. Merge. The next deploy of `apps/web` builds with the new origin. (A change
   to `intent.yaml` alone deploys nothing — touch `apps/web` in the same pull
   request, or let the next change to the site carry it.)

## Credits

The site is Clerk's Next.js auth starter
([clerk/nextjs-auth-starter-template](https://github.com/clerk/nextjs-auth-starter-template)),
the template behind Vercel's Clerk Authentication Starter.
