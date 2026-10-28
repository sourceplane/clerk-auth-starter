import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { clerkConnected } from "../../../lib/clerk";

// Until the site has Clerk's keys there is nobody to authenticate: say so,
// rather than let Clerk throw (lib/clerk.ts).
function notConnected() {
  return NextResponse.json({ error: "Clerk is not connected" }, { status: 503 });
}

export async function GET() {
  if (!clerkConnected) return notConnected();
  await auth.protect();

  return NextResponse.json({
    message: "This is a protected route",
    timestamp: new Date().toISOString(),
  });
}

export async function POST() {
  if (!clerkConnected) return notConnected();
  await auth.protect();

  return NextResponse.json({
    message: "Protected POST endpoint accessed successfully",
    timestamp: new Date().toISOString(),
  });
}
