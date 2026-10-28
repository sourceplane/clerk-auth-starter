# clerk-auth-starter — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a site built from it; the
pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md), with the site's `AGENTS.md`.

## What it is

Clerk's Next.js auth starter (clerk/nextjs-auth-starter-template, the
template behind Vercel's Clerk Authentication Starter) — sign-in and sign-up
with Clerk's prebuilt components, Clerk's middleware, a protected dashboard
showing the signed-in user, session and organization, and a protected API
route — built by OpenNext into one Cloudflare Worker with Static Assets,
packaged as an Orun baseline: `orun new --blueprint repo-blueprint.yaml`
builds a new site in its own repository and takes it to live on stage and
prod in one landing (`01-product`), then records what went live
(`03-docs`). A site is born without Clerk and shows a "connect Clerk" notice
until its owner stores a Clerk application's two keys.

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` — CK0 to CK2: the repository, the auth starter on Workers, and the baseline (blueprint, phases, tests) |
| Proven live | Not yet: proven offline in Baseline CI only (risk CK-A) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/clerk-auth-starter/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/clerk-auth-starter/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/clerk-auth-starter/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What the components are | `apps/web/docs/`, `tests/web/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one site from `baseline-v1` from the console and record its
   timings against the 5-minute estimate (closes CK-A); then the registry
   row goes public with the measured minutes.
2. On that site, store a Clerk development instance's keys for stage,
   redeploy, and sign in once through the real Clerk (closes CK-B).
