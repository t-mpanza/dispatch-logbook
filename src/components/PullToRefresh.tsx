import { useState, useRef, type ReactNode } from "react";
import { RefreshCw, Check } from "lucide-react";
import { vibrate } from "@/lib/haptics";

interface Props {
  onRefresh: () => Promise<any>;
  children: ReactNode;
  className?: string;
}

export function PullToRefresh({ onRefresh, children, className = "" }: Props) {
  const [pullY, setPullY] = useState(0);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [refreshSuccess, setRefreshSuccess] = useState(false);
  const [isPulling, setIsPulling] = useState(false);

  const startY = useRef(0);
  const isDragging = useRef(false);
  const threshold = 68;
  const maxPull = 110;
  const hasTriggeredHaptic = useRef(false);

  const handleTouchStart = (e: React.TouchEvent) => {
    // Only allow pull-to-refresh if user is at the very top of the page
    if (window.scrollY > 5 || isRefreshing) return;
    startY.current = e.touches[0].clientY;
    isDragging.current = true;
    hasTriggeredHaptic.current = false;
    setRefreshSuccess(false);
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (!isDragging.current || window.scrollY > 5 || isRefreshing) return;

    const currentY = e.touches[0].clientY;
    const deltaY = currentY - startY.current;

    if (deltaY > 0) {
      setIsPulling(true);
      // Logarithmic rubber band dampening
      const dampened = Math.min(maxPull, Math.pow(deltaY, 0.82) * 2.2);

      if (dampened >= threshold && !hasTriggeredHaptic.current) {
        vibrate("medium");
        hasTriggeredHaptic.current = true;
      } else if (dampened < threshold && hasTriggeredHaptic.current) {
        hasTriggeredHaptic.current = false;
      }

      setPullY(dampened);
    }
  };

  const handleTouchEnd = async () => {
    if (!isDragging.current) return;
    isDragging.current = false;
    setIsPulling(false);

    if (pullY >= threshold && !isRefreshing) {
      setIsRefreshing(true);
      setPullY(52); // snap to spinner height
      vibrate("success");

      try {
        await onRefresh();
        setRefreshSuccess(true);
        vibrate("light");
        await new Promise((r) => setTimeout(r, 600));
      } catch (err) {
        console.error("Pull-to-refresh failed:", err);
      } finally {
        setIsRefreshing(false);
        setPullY(0);
        setRefreshSuccess(false);
      }
    } else {
      setPullY(0);
    }
  };

  const progress = Math.min(1, pullY / threshold);
  const rotation = isRefreshing ? undefined : progress * 360;

  return (
    <div
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={handleTouchEnd}
      className={`relative ${className}`}
    >
      {/* ── Pull to refresh indicator ── */}
      <div
        style={{
          height: `${pullY}px`,
          opacity: pullY > 5 ? 1 : 0,
          transition: isPulling ? "none" : "all 0.3s cubic-bezier(0.16, 1, 0.3, 1)",
        }}
        className="overflow-hidden flex items-center justify-center pointer-events-none"
      >
        <div className="ios-glass-pill px-3 py-1.5 flex items-center gap-2 shadow-lg">
          {refreshSuccess ? (
            <>
              <Check size={14} className="text-emerald-400" />
              <span className="text-[11px] font-bold text-emerald-400 uppercase tracking-wider font-mono">
                Synced
              </span>
            </>
          ) : (
            <>
              <RefreshCw
                size={14}
                style={{
                  transform: rotation != null ? `rotate(${rotation}deg)` : undefined,
                }}
                className={`text-blue-400 ${isRefreshing ? "animate-spin" : ""}`}
              />
              <span className="text-[11px] font-bold text-slate-300 uppercase tracking-wider font-mono">
                {isRefreshing ? "Syncing…" : pullY >= threshold ? "Release to Sync" : "Pull to Sync"}
              </span>
            </>
          )}
        </div>
      </div>

      {/* ── Page Content ── */}
      {children}
    </div>
  );
}
