# clerk-auth-starter — Vercel's Clerk Authentication Starter on Cloudflare Workers

**Clerk's Next.js auth starter built by OpenNext into one Cloudflare Worker,
Clerk's middleware running in it, deployed by Orun to stage and prod on every
merge — a site that serves before it has a Clerk application and signs
people in once its owner stores the application's two keys — and the
baseline that makes a copy of it somebody else's in one landing.**

| | |
|---|---|
| Status | In progress — CK1 on main: the site runs on Workers |
| Upstream | [clerk/nextjs-auth-starter-template](https://github.com/clerk/nextjs-auth-starter-template), at `9e5619c` (2026-10-23) |
| Reference | [portfolio-starter-kit](https://github.com/sourceplane/portfolio-starter-kit) — the same scaffolding, tests and bootstrap; [cms-sanity](https://github.com/sourceplane/cms-sanity) — a SaaS's keys as optional Orun secrets; [subscription-payments](https://github.com/sourceplane/subscription-payments) — a secret handed to the Worker by the deploy |
| Key | `CK` |

## Read in this order

1. [design.md](design.md) — the template, how each Vercel piece maps to
   Cloudflare, the site before Clerk is connected, the repository and the
   build, and the alternative rejected.
2. [implementation-plan.md](implementation-plan.md) — the milestones and
   what each one lands.
3. [risks-and-open-questions.md](risks-and-open-questions.md) — what is not
   proven, and what was accepted.
4. [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) — what shipped, and
   every departure from the upstream template.

## Milestones

| Milestone | What it lands | Task |
|---|---|---|
| CK0 — the spec | the repository, its intent, CI, tooling and spec index; this doc set | CK-1 |
| CK1 — the auth starter on Workers | the template in `apps/web`, built by OpenNext into one Worker; the Clerk switch; the Worker-secret push; `tests/web` | CK-2 |
| CK2 — a baseline | the console card, the build document, the context pack and the baseline's tests | CK-3 |
