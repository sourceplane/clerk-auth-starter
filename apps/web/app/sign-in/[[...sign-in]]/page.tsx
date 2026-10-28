import { SignIn } from "@clerk/nextjs";
import { Suspense } from "react";
import { ConnectClerk } from "../../components/connect-clerk";
import { clerkConnected } from "../../../lib/clerk";

export default function Page() {
  if (!clerkConnected) return <ConnectClerk />;

  return (
    <div className="flex justify-center py-24">
      <Suspense>
        <SignIn />
      </Suspense>
    </div>
  );
}
