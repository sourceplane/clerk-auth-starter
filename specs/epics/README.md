# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`clerk-auth-starter/`](./clerk-auth-starter/) | **CK** | In progress (CK0) | Vercel's Clerk Authentication Starter — Clerk's Next.js auth starter — on Cloudflare Workers + Static Assets through OpenNext, with Clerk's keys as Orun secrets, and an Orun baseline that instantiates it (CK2) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
