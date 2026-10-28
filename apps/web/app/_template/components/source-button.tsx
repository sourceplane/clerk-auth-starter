import Link from "next/link";
import { clsx } from "clsx";
import { SOURCE_URL } from "../../site";

// Where the template's "Deploy to Vercel" button stood: this site's own
// repository, which is what deploys it (every merge to main, through Orun).
export function SourceButton({ className }: { className?: string }) {
  return (
    <Link
      href={SOURCE_URL}
      target="_blank"
      className={clsx(
        "inline-flex items-center gap-3 bg-black text-white px-4 py-3 text-sm rounded-full hover:bg-gray-800 transition-colors cursor-pointer font-medium",
        className
      )}
    >
      <svg
        className="h-3.5 w-3.5"
        viewBox="0 0 16 16"
        fill="currentColor"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path d="M8 0.198C3.58 0.198 0 3.78 0 8.198c0 3.535 2.292 6.533 5.47 7.59.4.075.547-.172.547-.385 0-.19-.007-.693-.01-1.36-2.226.483-2.695-1.073-2.695-1.073-.364-.923-.89-1.17-.89-1.17-.725-.496.056-.486.056-.486.803.056 1.225.824 1.225.824.714 1.223 1.873.87 2.33.665.072-.517.278-.87.507-1.07-1.777-.2-3.644-.888-3.644-3.953 0-.873.31-1.587.823-2.147-.09-.202-.36-1.015.07-2.117 0 0 .67-.215 2.2.82a7.67 7.67 0 0 1 4 0c1.52-1.035 2.19-.82 2.19-.82.43 1.102.16 1.915.08 2.117.51.56.82 1.274.82 2.147 0 3.073-1.87 3.75-3.65 3.947.28.24.54.73.54 1.48 0 1.07-.01 1.93-.01 2.19 0 .21.14.46.55.38C13.71 14.728 16 11.728 16 8.198 16 3.78 12.418.198 8 .198Z" />
      </svg>
      <span>Source on GitHub</span>
    </Link>
  );
}
