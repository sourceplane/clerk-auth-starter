import { Metadata } from "next";
import { SITE_NAME, SITE_URL } from "../../site";

export const templateMetadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: SITE_NAME,
  description:
    "A simple and powerful Next.js template featuring authentication and user management powered by Clerk.",
  openGraph: { images: ["/og.png"] },
};

// Default metadata for when template is removed
export const defaultMetadata: Metadata = {
  title: SITE_NAME,
  description: "My Next.js app with Clerk authentication",
};
