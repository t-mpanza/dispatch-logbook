# Design System

## Theme

Single theme: **Midnight Indigo** dark mode. No light mode exists. No theme toggle.

Background is a very dark desaturated indigo (`oklch(0.13 0.04 275)`), not pure black. This is intentional — pure black looks cheap on OLED.

---

## CSS custom properties (`src/styles.css`)

All tokens defined on `:root`. Tailwind v4 consumes them via `@theme inline {}`.

### Surfaces

| Token | Value | Usage |
|---|---|---|
| `--background` | `oklch(0.13 0.04 275)` | Page background |
| `--foreground` | `oklch(0.96 0.01 270)` | Body text |
| `--surface` | `oklch(0.17 0.045 275)` | Cards, panels |
| `--surface-elevated` | `oklch(0.21 0.05 275)` | Elevated within-card elements |

### Primary / Accent

| Token | Value | Usage |
|---|---|---|
| `--primary` | `oklch(0.62 0.21 275)` | Buttons, active states |
| `--primary-foreground` | `oklch(0.98 0.005 270)` | Text on primary |
| `--primary-glow` | `oklch(0.72 0.22 280)` | Icons, labels, accent text — slightly brighter/more saturated |
| `--accent` | `oklch(0.72 0.22 280)` | Same as `primary-glow` |
| `--accent-foreground` | `oklch(0.13 0.04 275)` | Text on accent backgrounds |

### Muted / Secondary

| Token | Value | Usage |
|---|---|---|
| `--secondary` | `oklch(0.24 0.05 275)` | Secondary backgrounds |
| `--muted` | `oklch(0.22 0.04 275)` | Muted backgrounds |
| `--muted-foreground` | `oklch(0.68 0.03 270)` | Placeholder text, metadata |

### Semantic

| Token | Value | Usage |
|---|---|---|
| `--destructive` | `oklch(0.62 0.22 25)` | Delete actions, errors |
| `--destructive-foreground` | `oklch(0.98 0.005 270)` | Text on destructive |
| `--border` | `oklch(0.27 0.05 275)` | All borders |
| `--input` | `oklch(0.24 0.05 275)` | Input backgrounds |
| `--ring` | `oklch(0.62 0.21 275)` | Focus rings |

### Card / Popover (same as surface)

| Token | Value |
|---|---|
| `--card` | same as `--surface` |
| `--card-foreground` | same as `--foreground` |
| `--popover` | `oklch(0.19 0.05 275)` |
| `--popover-foreground` | same as `--foreground` |

---

## Composite tokens

| Token | Value | Usage |
|---|---|---|
| `--gradient-primary` | `linear-gradient(135deg, var(--primary), var(--primary-glow))` | FAB, primary CTAs, CounterPanel header |
| `--gradient-surface` | `linear-gradient(180deg, var(--surface), var(--background))` | Fade effects |
| `--shadow-glow` | `0 10px 40px -10px oklch(0.62 0.21 275 / 0.5)` | Purple bloom on primary elements |
| `--shadow-elevated` | `0 8px 24px -8px oklch(0.05 0.02 275 / 0.6)` | Subtle shadow on elevated surfaces |

---

## Border radius scale

| Token | Value |
|---|---|
| `--radius` | `0.875rem` (base) |
| `--radius-sm` | `base - 4px` |
| `--radius-md` | `base - 2px` |
| `--radius-lg` | `base` |
| `--radius-xl` | `base + 4px` |
| `--radius-2xl` | `base + 8px` |

In practice: cards use `rounded-xl`, the FAB and nav buttons use `rounded-full`, CounterPanel uses `rounded-2xl`.

---

## Typography

System font stack — no Google Fonts loaded:
```css
font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
```

Entry titles are rendered in `font-mono uppercase tracking-wider` — intentional operational/logbook aesthetic.

Section labels / eyebrows: `text-xs uppercase tracking-[0.2em]` in `text-primary-glow`.

Timeline timestamps: `tabular-nums text-[10px]`.

---

## Spacing conventions

- Page horizontal padding: `px-5`
- Header: `pt-8 pb-4`
- Card internal padding: `p-4` (list items), `p-3` (input cards)
- Stack gap between cards: `space-y-2.5`
- Bottom nav safe area: `pb-[max(0.5rem,env(safe-area-inset-bottom))]`
- Bottom padding for scrollable content (above fixed nav): `pb-20`

---

## Tailwind v4 setup

```css
@import "tailwindcss" source(none);
@source "../src";
@import "tw-animate-css";
@custom-variant dark (&:is(.dark *));
```

`source(none)` + explicit `@source "../src"` means Tailwind only scans `src/` for class names.  
`@theme inline {}` exposes all CSS vars as Tailwind color/radius utilities.

---

## Interaction patterns

- `active:scale-95` — pressed state on all tappable elements
- `hover:border-primary/50` — subtle border highlight on hover
- `transition-all` / `transition-colors` — 150ms default
- `backdrop-blur-xl` — sticky headers and bottom nav
- `animate-pulse` — recording indicator dot, camera loading icon
