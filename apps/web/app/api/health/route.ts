import { NextResponse } from "next/server";
import { clerkConnected } from "../../../lib/clerk";

// What every deploy's smoke test reads: whether the Worker holds what its
// build expects. A site built with Clerk's keys needs CLERK_SECRET_KEY at
// request time (a Worker secret the deploy sets); one built without them
// needs nothing. Names only — never a value.
export const dynamic = "force-dynamic";

export function GET() {
  const secretKey = Boolean(process.env.CLERK_SECRET_KEY);
  const ok = !clerkConnected || secretKey;
  return NextResponse.json(
    { ok, clerk: clerkConnected ? "connected" : "not-connected" },
    { status: ok ? 200 : 503 }
  );
}
