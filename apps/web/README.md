# apps/web — the site

Clerk's Next.js auth starter
([clerk/nextjs-auth-starter-template](https://github.com/clerk/nextjs-auth-starter-template)),
running on Cloudflare Workers + Static Assets:

- Sign-in and sign-up with Clerk's prebuilt components (`app/sign-in`)
- A protected dashboard showing the signed-in user, session and organization
  (`app/dashboard`), and a protected API route (`app/api/protected`)
- Clerk's middleware in `proxy.ts` (Next 16's name for it)
- Tailwind v4, Geist font

Clerk is connected when the build has both of its keys (`lib/clerk.ts`);
until then every page renders with a "connect Clerk" notice where sign-in
would be. The site's name and the repository its header links to are in
`app/site.ts`.

```bash
cp .env.example .env.local   # and fill in the two Clerk keys
pnpm dev        # next dev on http://localhost:3000
pnpm build      # next build + opennextjs-cloudflare build → .open-next/
pnpm preview    # wrangler dev over the built Worker (CLERK_SECRET_KEY from .dev.vars)
```

How it is deployed — per environment, on merge to `main` — is the
repository's README and `component.yaml` beside this file.
