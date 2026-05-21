import { useEffect } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Capacitor } from "@capacitor/core";
import { StatusBar, Style } from "@capacitor/status-bar";
import { CapacitorUpdater } from "@capgo/capacitor-updater";
import { Toaster, toast } from "sonner";
import { supabase } from "@/lib/supabase";
import { fullSync } from "@/lib/sync";
import {
  Outlet,
  Link,
  createRootRouteWithContext,
  useRouter,
  HeadContent,
  Scripts,
} from "@tanstack/react-router";

import appCss from "../styles.css?url";

function NotFoundComponent() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="max-w-md text-center">
        <h1 className="text-7xl font-bold text-foreground">404</h1>
        <h2 className="mt-4 text-xl font-semibold text-foreground">Page not found</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          The page you're looking for doesn't exist or has been moved.
        </p>
        <div className="mt-6">
          <Link
            to="/"
            className="inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            Go home
          </Link>
        </div>
      </div>
    </div>
  );
}

function ErrorComponent({ error, reset }: { error: Error; reset: () => void }) {
  console.error(error);
  const router = useRouter();

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="max-w-md text-center">
        <h1 className="text-xl font-semibold tracking-tight text-foreground">
          This page didn't load
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Something went wrong on our end. You can try refreshing or head back home.
        </p>
        <div className="mt-6 flex flex-wrap justify-center gap-2">
          <button
            onClick={() => {
              router.invalidate();
              reset();
            }}
            className="inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            Try again
          </button>
          <a
            href="/"
            className="inline-flex items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
          >
            Go home
          </a>
        </div>
      </div>
    </div>
  );
}

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      {
        name: "viewport",
        content:
          "width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no",
      },
      { title: "Dispatch Diary" },
      {
        name: "description",
        content:
          "Fast-capture operational diary for dispatch — voice, photo, video, files. On-device.",
      },
      { name: "theme-color", content: "#0a0a1a" },
      { name: "apple-mobile-web-app-capable", content: "yes" },
      { name: "apple-mobile-web-app-status-bar-style", content: "black-translucent" },
      { name: "apple-mobile-web-app-title", content: "Diary" },
      { property: "og:title", content: "Dispatch Diary" },
      {
        property: "og:description",
        content: "On-device voice, photo, video and file diary for dispatch work.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:title", content: "Dispatch Diary" },
      { name: "description", content: "A mobile-first diary app for documenting operational incidents with voice, photos, video, and files." },
      { property: "og:description", content: "A mobile-first diary app for documenting operational incidents with voice, photos, video, and files." },
      { name: "twitter:description", content: "A mobile-first diary app for documenting operational incidents with voice, photos, video, and files." },

      { name: "twitter:card", content: "summary_large_image" },
    ],
    links: [
      { rel: "stylesheet", href: appCss },
      { rel: "manifest", href: `${import.meta.env.BASE_URL}manifest.webmanifest` },
      { rel: "icon", href: `${import.meta.env.BASE_URL}icon-512.png`, type: "image/png" },
      { rel: "apple-touch-icon", href: `${import.meta.env.BASE_URL}icon-512.png` },
    ],
  }),
  shellComponent: RootShell,
  component: RootComponent,
  notFoundComponent: NotFoundComponent,
  errorComponent: ErrorComponent,
});


function RootShell({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}

async function checkForOTA() {
  if (!Capacitor.isNativePlatform()) return;
  try {
    const res = await fetch("https://api.github.com/repos/t-mpanza/dispatch-logbook/releases/latest");
    if (!res.ok) return;
    const release = await res.json();
    const latestTag = release.tag_name;
    const currentTag = import.meta.env.VITE_APP_VERSION || "v1.0.0";
    
    // Only update if there's a newer tag and we found the dist.zip
    if (latestTag && latestTag !== currentTag) {
      const asset = release.assets?.find((a: any) => a.name === "dist.zip");
      if (asset) {
        console.log(`Downloading OTA update: ${latestTag}`);
        const bundle = await CapacitorUpdater.download({
          url: asset.browser_download_url,
          version: latestTag,
        });
        
        toast("App Update Ready", {
          description: `Version ${latestTag} has been downloaded.`,
          action: {
            label: "Restart",
            onClick: () => CapacitorUpdater.set({ id: bundle.id })
          },
          duration: Infinity
        });
      }
    }
  } catch (err) {
    console.error("OTA update check failed", err);
  }
}

function RootComponent() {
  const { queryClient } = Route.useRouteContext();

  useEffect(() => {
    if (typeof window !== "undefined" && "serviceWorker" in navigator) {
      navigator.serviceWorker
        .register(`${import.meta.env.BASE_URL}sw.js`, {
          scope: import.meta.env.BASE_URL,
        })
        .catch((err) => console.error("SW registration failed:", err));
    }

    if (Capacitor.isNativePlatform()) {
      CapacitorUpdater.notifyAppReady().catch(console.error);
      checkForOTA();

      if (Capacitor.getPlatform() === "android") {
        StatusBar.setOverlaysWebView({ overlay: false }).catch(console.error);
        StatusBar.setBackgroundColor({ color: "#0a0a1a" }).catch(console.error);
      }
      StatusBar.setStyle({ style: Style.Dark }).catch(console.error);
    }

    // Background cloud sync on launch (if already signed in)
    fullSync().catch(console.error);

    // Re-sync whenever the user signs in
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_IN") {
        fullSync().catch(console.error);
      }
    });
    return () => subscription.unsubscribe();
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <Outlet />
      <Toaster position="top-center" theme="dark" />
    </QueryClientProvider>
  );
}
