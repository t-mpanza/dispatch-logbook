import { useState, useRef, useEffect, type ReactNode } from "react";
import { vibrate } from "@/lib/haptics";

export interface SwipeAction {
  id: string;
  label: string;
  icon: ReactNode;
  color: string; // e.g. "bg-rose-600 text-white"
  onClick: () => void;
}

interface Props {
  children: ReactNode;
  leftActions?: SwipeAction[];
  rightActions?: SwipeAction[];
  className?: string;
  disabled?: boolean;
}

export function SwipeableItem({
  children,
  leftActions = [],
  rightActions = [],
  className = "",
  disabled = false,
}: Props) {
  const [offsetX, setOffsetX] = useState(0);
  const [isOpen, setIsOpen] = useState<"left" | "right" | null>(null);
  const [isDragging, setIsDragging] = useState(false);

  const touchStartX = useRef(0);
  const touchStartY = useRef(0);
  const isHorizontalScroll = useRef<boolean | null>(null);
  const currentOffset = useRef(0);
  const containerRef = useRef<HTMLDivElement>(null);
  const hasTriggeredHaptic = useRef(false);

  const actionWidth = 72; // width per action button in px
  const maxRightOffset = leftActions.length * actionWidth;
  const maxLeftOffset = rightActions.length * actionWidth;

  const close = () => {
    setOffsetX(0);
    setIsOpen(null);
    currentOffset.current = 0;
    hasTriggeredHaptic.current = false;
  };

  useEffect(() => {
    const handleGlobalTouch = (e: TouchEvent) => {
      if (
        containerRef.current &&
        !containerRef.current.contains(e.target as Node) &&
        (offsetX !== 0 || isOpen !== null)
      ) {
        close();
      }
    };
    window.addEventListener("touchstart", handleGlobalTouch, { passive: true });
    return () => window.removeEventListener("touchstart", handleGlobalTouch);
  }, [offsetX, isOpen]);

  if (disabled || (leftActions.length === 0 && rightActions.length === 0)) {
    return <div className={className}>{children}</div>;
  }

  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartX.current = e.touches[0].clientX;
    touchStartY.current = e.touches[0].clientY;
    isHorizontalScroll.current = null;
    setIsDragging(true);
    hasTriggeredHaptic.current = false;
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (!isDragging) return;

    const deltaX = e.touches[0].clientX - touchStartX.current;
    const deltaY = e.touches[0].clientY - touchStartY.current;

    // Detect gesture direction on initial movement
    if (isHorizontalScroll.current === null) {
      if (Math.abs(deltaY) > 8 && Math.abs(deltaY) > Math.abs(deltaX)) {
        isHorizontalScroll.current = false; // Vertical scroll, cancel swipe
        setIsDragging(false);
        return;
      }
      if (Math.abs(deltaX) > 8) {
        isHorizontalScroll.current = true; // Horizontal swipe confirmed
      }
    }

    if (!isHorizontalScroll.current) return;

    let targetX = currentOffset.current + deltaX;

    // Boundary resistance calculations
    if (targetX > 0) {
      if (leftActions.length === 0) {
        targetX = Math.pow(targetX, 0.65); // high resistance when no actions
      } else if (targetX > maxRightOffset) {
        targetX = maxRightOffset + Math.pow(targetX - maxRightOffset, 0.7);
      }
    } else if (targetX < 0) {
      if (rightActions.length === 0) {
        targetX = -Math.pow(Math.abs(targetX), 0.65);
      } else if (Math.abs(targetX) > maxLeftOffset) {
        targetX = -(maxLeftOffset + Math.pow(Math.abs(targetX) - maxLeftOffset, 0.7));
      }
    }

    // Trigger haptic feedback when entering the action snap zone
    if (
      !hasTriggeredHaptic.current &&
      ((targetX < -actionWidth * 0.7 && rightActions.length > 0) ||
        (targetX > actionWidth * 0.7 && leftActions.length > 0))
    ) {
      vibrate("light");
      hasTriggeredHaptic.current = true;
    }

    setOffsetX(targetX);
  };

  const handleTouchEnd = () => {
    if (!isDragging || !isHorizontalScroll.current) {
      setIsDragging(false);
      return;
    }

    setIsDragging(false);

    // Snap to left or right action trays if pulled past 40% of action width
    if (offsetX < -actionWidth * 0.5 && rightActions.length > 0) {
      setOffsetX(-maxLeftOffset);
      currentOffset.current = -maxLeftOffset;
      setIsOpen("right");
    } else if (offsetX > actionWidth * 0.5 && leftActions.length > 0) {
      setOffsetX(maxRightOffset);
      currentOffset.current = maxRightOffset;
      setIsOpen("left");
    } else {
      close();
    }
  };

  return (
    <div
      ref={containerRef}
      className={`relative overflow-hidden rounded-2xl select-none touch-pan-y ${className}`}
    >
      {/* ── Left Actions Tray (revealed on swiping right) ── */}
      {leftActions.length > 0 && (
        <div
          className="absolute inset-y-0 left-0 flex items-stretch z-0"
          style={{ width: `${maxRightOffset}px` }}
        >
          {leftActions.map((action) => (
            <button
              key={action.id}
              onClick={() => {
                vibrate("medium");
                action.onClick();
                close();
              }}
              style={{ width: `${actionWidth}px` }}
              className={`flex flex-col items-center justify-center gap-1 font-bold text-[10px] uppercase tracking-wider transition-opacity active:opacity-75 ${action.color}`}
            >
              {action.icon}
              <span>{action.label}</span>
            </button>
          ))}
        </div>
      )}

      {/* ── Right Actions Tray (revealed on swiping left) ── */}
      {rightActions.length > 0 && (
        <div
          className="absolute inset-y-0 right-0 flex items-stretch z-0"
          style={{ width: `${maxLeftOffset}px` }}
        >
          {rightActions.map((action) => (
            <button
              key={action.id}
              onClick={() => {
                vibrate("medium");
                action.onClick();
                close();
              }}
              style={{ width: `${actionWidth}px` }}
              className={`flex flex-col items-center justify-center gap-1 font-bold text-[10px] uppercase tracking-wider transition-opacity active:opacity-75 ${action.color}`}
            >
              {action.icon}
              <span>{action.label}</span>
            </button>
          ))}
        </div>
      )}

      {/* ── Main Foreground Card ── */}
      <div
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
        onTouchCancel={handleTouchEnd}
        style={{
          transform: `translate3d(${offsetX}px, 0, 0)`,
          transition: isDragging
            ? "none"
            : "transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.15)",
        }}
        className="relative z-10 will-change-transform bg-[#0b0c12]"
      >
        {children}
      </div>
    </div>
  );
}
