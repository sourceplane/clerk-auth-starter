import { CLERK_DASHBOARD_URL } from "../../lib/clerk";

// What stands where Clerk's sign-in would be until the site has a Clerk
// application's keys (lib/clerk.ts). `compact` is the landing hero's button
// row; the full notice is the sign-in and dashboard pages.
export function ConnectClerk({ compact = false }: { compact?: boolean }) {
  if (compact) {
    return (
      <a
        href={CLERK_DASHBOARD_URL}
        target="_blank"
        data-clerk="not-connected"
        className="px-4 py-2 rounded-full bg-[#F4F4F5] text-[#131316] text-sm font-semibold"
      >
        Connect Clerk to sign in
      </a>
    );
  }
  return (
    <div
      data-clerk="not-connected"
      className="max-w-120 mx-auto my-24 p-8 rounded-xl bg-[#fafafa] ring-1 ring-gray-950/5"
    >
      <h1 className="text-xl font-semibold text-[#131316] tracking-tight">
        Clerk is not connected yet
      </h1>
      <p className="text-[0.8125rem]/5 text-[#5E5F6E] mt-3">
        Sign-in, sign-up and the dashboard run on a Clerk application. Create
        one in the{" "}
        <a href={CLERK_DASHBOARD_URL} target="_blank" className="underline">
          Clerk dashboard
        </a>
        , store its publishable key and secret key as this environment&apos;s{" "}
        <code className="font-mono">CLERK_PUBLISHABLE_KEY</code> and{" "}
        <code className="font-mono">CLERK_SECRET_KEY</code>, and redeploy. The
        README&apos;s &ldquo;Connect Clerk&rdquo; says how.
      </p>
    </div>
  );
}
