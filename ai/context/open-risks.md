# clerk-auth-starter — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/clerk-auth-starter/risks-and-open-questions.md`; this page lists
only what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| CK-A | `baseline-v1` is not yet proven live; it is proven offline in Baseline CI (the offline bootstrap, the stage lane's own steps, the site served and smoke-tested without Clerk and with made-up keys) | OPEN | One console bootstrap from `baseline-v1` |
| CK-B | A signed-in session through the real Clerk has not run on the Worker: offline, Clerk's middleware answers signed-out requests (no network needed), but a session's token verification fetches Clerk's keys, and the first `wrangler secret bulk` on a Worker that does not exist yet has not run | OPEN | Clerk development keys stored on a live site's stage, redeployed, one sign-in to `/dashboard` |
| CK-E | Clerk's proxy runs as Next 16 Node.js middleware, which OpenNext calls experimental on Cloudflare | WATCH | Holds while every e2e serves it; subscription-payments runs the same shape |

Accepted, and worth knowing before you change them: CK-C (Clerk's UI from
its CDN), CK-D (Next 16.3.8, not 16.4.2), CK-F (the upstream repository
carries no LICENSE file).
