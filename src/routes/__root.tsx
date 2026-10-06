import {
  HeadContent,
  Outlet,
  Scripts,
  createRootRouteWithContext,
  useRouter,
} from "@tanstack/react-router";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useEffect } from "react";
import { Toaster, toast } from "sonner";
import { Capacitor } from "@capacitor/core";
import { App as CapApp } from "@capacitor/app";
import { StatusBar, Style } from "@capacitor/status-bar";
import { SplashScreen } from "@capacitor/splash-screen";
import { Network } from "@capacitor/network";
import { CapacitorUpdater } from "@capgo/capacitor-updater";
import { fullSync, setupRealtimeSync } from "@/lib/sync";
import { supabase } from "@/lib/supabase";
import { getStoredTheme, applyTheme } from "@/lib/theme";

import appCss from "../styles.css?url";

function NotFoundComponent() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="text-center">
        <p className="text-xs uppercase tracking-[0.2em] text-primary-glow font-bold">404</p>
        <h1 className="mt-2 text-2xl font-bold tracking-tight text-slate-100">Page Not Found</h1>
        <p className="mt-2 text-sm text-slate-400">
          The page you are looking for does not exist.
        </p>
        <a
          href="/"
          className="mt-6 inline-flex items-center justify-center rounded-2xl bg-blue-600 px-5 py-2.5 text-xs font-bold uppercase tracking-wider text-white shadow-lg ios-press"
        >
          Return to Today
        </a>
      </div>
    </div>
  );
}

function ErrorComponent({ error }: { error: Error }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="text-center max-w-md">
        <p className="text-xs uppercase tracking-[0.2em] text-rose-400 font-bold">Application Error</p>
        <h1 className="mt-2 text-2xl font-bold tracking-tight text-slate-100">Something went wrong</h1>
        <p className="mt-2 text-xs text-slate-400 font-mono bg-black/40 p-3 rounded-xl border border-white/10 text-left overflow-auto max-h-40">
          {error.message}
        </p>
        <button
          onClick={() => window.location.reload()}
          className="mt-6 inline-flex items-center justify-center rounded-2xl bg-blue-600 px-5 py-2.5 text-xs font-bold uppercase tracking-wider text-white shadow-lg ios-press"
        >
          Reload Application
        </button>
      </div>
    </div>
  );
}

export const Route = createRootRouteWithContext<{
  queryClient: QueryClient;
}>()({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      {
        name: "viewport",
        content: "width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no",
      },
      { title: "Dispatch Diary" },
      {
        name: "description",
        content:
          "Fast-capture operational diary for dispatch — voice, photo, video, files. Local-first & offline resilient.",
      },
      { name: "theme-color", content: "#0b0c12" },
      { name: "apple-mobile-web-app-capable", content: "yes" },
      { name: "apple-mobile-web-app-status-bar-style", content: "black-translucent" },
      { name: "apple-mobile-web-app-title", content: "Dispatch Diary" },
      { property: "og:title", content: "Dispatch Diary" },
      {
        property: "og:description",
        content: "Local-first voice, photo, video and loading sheet diary for dispatch work.",
      },
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
    const res = await fetch(
      "https://api.github.com/repos/t-mpanza/dispatch-logbook/releases/latest"
    );
    if (!res.ok) return;
    const release = await res.json();
    const latestTag = release.tag_name;
    const currentTag = import.meta.env.VITE_APP_VERSION || "v1.0.0";

    if (latestTag && latestTag !== currentTag) {
      const asset = release.assets?.find((a: any) => a.name === "dist.zip");
      if (asset) {
        console.log(`Downloading OTA update: ${latestTag}`);
        const bundle = await CapacitorUpdater.download({
          url: asset.browser_download_url,
          version: latestTag,
        });

        toast("App Update Ready", {
          description: `Version ${latestTag} downloaded. Tap to restart.`,
          action: {
            label: "Restart",
            onClick: () => CapacitorUpdater.set({ id: bundle.id }),
          },
          duration: Infinity,
        });
      }
    }
  } catch (err) {
    console.error("OTA update check failed", err);
  }
}

function RootComponent() {
  const { queryClient } = Route.useRouteContext();
  const router = useRouter();

  useEffect(() => {
    applyTheme(getStoredTheme());

    if (typeof window !== "undefined" && "serviceWorker" in navigator) {
      navigator.serviceWorker
        .register(`${import.meta.env.BASE_URL}sw.js`, {
          scope: import.meta.env.BASE_URL,
        })
        .catch((err) => console.error("SW registration failed:", err));
    }

    if (Capacitor.isNativePlatform()) {
      CapacitorUpdater.notifyAppReady().catch(console.error);
      SplashScreen.hide().catch(console.error);
      checkForOTA();

      if (Capacitor.getPlatform() === "android") {
        StatusBar.setOverlaysWebView({ overlay: false }).catch(console.error);
        StatusBar.setBackgroundColor({ color: "#0b0c12" }).catch(console.error);
      }
      StatusBar.setStyle({ style: Style.Dark }).catch(console.error);
    }

    // Smart Android hardware back button handler
    let lastBackPress = 0;
    const backHandler = CapApp.addListener("backButton", () => {
      const currentPathName = window.location.pathname;
      const baseUrl = import.meta.env.BASE_URL.replace(/\/$/, "");
      const relativePath = currentPathName.startsWith(baseUrl)
        ? currentPathName.slice(baseUrl.length)
        : currentPathName;

      const isRoot = !relativePath || relativePath === "/" || relativePath === "";

      if (!isRoot) {
        if (router.history.canGoBack()) {
          router.history.back();
        } else {
          router.navigate({ to: "/" });
        }
      } else {
        const now = Date.now();
        if (now - lastBackPress < 2000) {
          CapApp.exitApp();
        } else {
          lastBackPress = now;
          toast("Press back again to exit", { duration: 2000 });
        }
      }
    });

    // Background cloud sync on launch with queryClient cache invalidation
    fullSync(queryClient).catch(console.error);

    // Setup Supabase Realtime synchronization across devices
    const cleanupRealtime = setupRealtimeSync(queryClient);

    // Auto-sync whenever internet connection is restored (Capacitor Network + Web)
    const networkHandler = Network.addListener("networkStatusChange", (status) => {
      if (status.connected) {
        fullSync(queryClient).catch(console.error);
      }
    });

    const handleOnline = () => {
      fullSync(queryClient).catch(console.error);
    };
    window.addEventListener("online", handleOnline);

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_IN") {
        fullSync(queryClient).catch(console.error);
      }
    });

    return () => {
      subscription.unsubscribe();
      cleanupRealtime();
      window.removeEventListener("online", handleOnline);
      networkHandler.then((h) => h.remove());
      backHandler.then((h) => h.remove());
    };
  }, [router, queryClient]);

  return (
    <QueryClientProvider client={queryClient}>
      <Outlet />
      <Toaster position="top-center" theme="dark" />
    </QueryClientProvider>
  );
}
