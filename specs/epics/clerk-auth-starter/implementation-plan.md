# clerk-auth-starter — implementation plan

Three milestones, each one reviewed pull request (CK0 is the repository's
first commit), each green before it merges.

## CK0 — the spec (CK-1)

The repository is born: `intent.yaml` with the placeholder workspace
`ws_CHANGE_ME`, `ci.yml` (byte for byte turso-starter's, which plans nothing
until the workspace is set), the shared TypeScript and ESLint configuration,
the spec index, this doc set and the task contracts.

## CK1 — the auth starter on Workers (CK-2)

- The template's `app/`, `public/`, `proxy.ts` and configuration in
  `apps/web`; its dependencies on Next 16.3.8, with `@opennextjs/cloudflare`
  and `wrangler`.
- `next.config.ts`: `output: 'standalone'`, the workspace root for the trace
  and Turbopack, Cache Components off, the Clerk decision and the template's
  Clerk routes as defaults. `open-next.config.ts` with the static-assets
  incremental cache; `wrangler.jsonc`.
- `lib/clerk.ts` and `app/components/connect-clerk.tsx`: every Clerk surface
  — the provider, the landing's button, `/sign-in`, `/dashboard`,
  `/api/protected`, the proxy — reads the switch. `/api/health`.
- `SITE_NAME`, `SOURCE_URL` and `SITE_URL` in `app/site.ts`; the template's
  metadata reads them. The "Deploy to Vercel" button is the source link.
- `tooling/wire/worker-secrets.mjs`; `component.yaml`: the optional secret
  refs, the deploy contract (the origin per environment, the secret push)
  and its smoke. `tests/web`: the identity, the switch and the build's
  decision, the health and protected routes, the secret push.
- The README's "How it maps to Vercel".

## CK2 — a baseline (CK-3)

portfolio-starter-kit's machinery, renamed: `blueprint.yaml`,
`repo-blueprint.yaml` (Clerk's keyless `.clerk` directory ignored),
`.baseline/` (identity, the product's README with "Connect Clerk", its
`AGENTS.md`, task contracts), `tooling/rebrand`, `tooling/bootstrap`,
`hooks/render-deployment-docs.sh` (probing `/` and `/api/health`, naming the
Clerk keys), `docs/phases/`, the context pack, `testing/` (the leak and
placement gates on this tree's files, the optional Clerk refs checked in the
plan; the e2e tier building and serving the site without Clerk and with
made-up keys) and `baseline.yml` / `tag.yml`.
