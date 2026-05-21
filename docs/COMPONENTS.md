# Components

---

## `AppShell`

**File**: `src/components/AppShell.tsx`  
**Used by**: Today, Counter, Search, Archive pages

### Props
```ts
{ children: ReactNode }
```

### What it does
- Layout container: `min-h-screen flex flex-col max-w-md mx-auto`
- Calls `rescheduleAll()` on mount (re-arms reminder timeouts)
- Fixed bottom nav with 4 links: Today (`/`), Counter (`/counter`), Search (`/search`), Archive (`/archive`)
- Active state detection: exact match for `/`, prefix match for all others
- Safe-area-inset padding on nav for iOS notch/home indicator
- Does **not** render on `entry.$id`, `entry.new`, or `day.$date` routes — those have their own headers

---

## `EntryListItem`

**File**: `src/components/EntryListItem.tsx`  
**Used by**: Today, Search, Archive (day drilldown via `day.$date`)

### Props
```ts
{ entry: Entry }
```

### What it renders
- `<Link>` card → `/entry/:id`
- Title (monospace, uppercase, truncated)
- Creation time (HH:mm)
- First note preview (2-line clamp)
- Attachment count chips: Mic/Image/Video/Paperclip icons with counts (hidden if 0)
- Trip total with Truck icon (only if `Array.isArray(entry.trips)`)
- Tags (truncated, `#tag` format, in `primary-glow` colour)

---

## `CaptureBar`

**File**: `src/components/CaptureBar.tsx`  
**Used by**: `entry.$id.tsx`

### Props
```ts
{
  onAttachment: (a: Attachment) => void;
  onStartVoice: () => void;
  disabled?: boolean;
}
```

### What it does
- 4-button grid: Voice | Photo | Video | File
- **Voice**: calls `onStartVoice` (parent swaps in `<VoiceRecorder>`)
- **Photo**: opens `<InAppCamera>` overlay (not the system file picker)
- **Video**: triggers hidden `<input type="file" accept="video/*" capture="environment">`
- **File**: triggers hidden `<input type="file" multiple>` (any file type)

### Image handling
- Images are downscaled via `downscaleImage()` before calling `onAttachment`
- Multiple files supported for photo and file inputs
- Yield between files: `await new Promise(r => setTimeout(r, 0))`
- Processing state shown with `"Processing photo…"` label

### Camera fallback
If `InAppCamera` calls `onFallback()`, it closes and programmatically clicks the hidden `photoRef` input to use the system camera instead.

---

## `InAppCamera`

**File**: `src/components/InAppCamera.tsx`  
**Used by**: `CaptureBar`

### Props
```ts
{
  onCapture: (blob: Blob) => void;
  onClose: () => void;
  onFallback: () => void;
}
```

### What it does
- Full-screen camera overlay (z-50, fixed inset-0, black bg)
- Uses `navigator.mediaDevices.getUserMedia` to get video stream
- Prefers `facingMode: "environment"` (rear camera)
- Camera switch button if `enumerateDevices()` finds multiple video inputs
- Capture: draws current video frame to canvas, exports as JPEG blob (quality 0.90)
- "Use System" button → calls `onFallback()`

### Known issues
- Stream cleanup in the `facingMode` effect references stale `stream` state — can leak tracks on camera switch (see `KNOWN_GAPS.md`)
- Falls back to `onFallback()` on `getUserMedia` error (shows sonner toast first)

---

## `VoiceRecorder`

**File**: `src/components/VoiceRecorder.tsx`  
**Used by**: `entry.$id.tsx`

### Props
```ts
{
  onSave: (a: Attachment) => void;
  onCancel: () => void;
}
```

### What it does
- Starts recording immediately on mount (`useEffect` → `start()`)
- Uses `MediaRecorder` with `audio/webm` if supported, otherwise browser default
- Elapsed timer updates every 200ms
- "Stop & save" → stops recorder, assembles `Blob` from chunks, calls `onSave(attachment)`
- Cancel → stops recorder without saving
- Cleanup on unmount: calls `stop(true)` (cancel mode)

---

## `AttachmentView`

**File**: `src/components/AttachmentView.tsx`  
**Used by**: `entry.$id.tsx` timeline

### Props
```ts
{
  attachment: Attachment;
  onRemove?: () => void;
  onOpenImage?: (a: Attachment) => void;
}
```

### Rendering by kind
| Kind | Renders |
|---|---|
| `image` | `<img>` + tap opens lightbox via `onOpenImage` |
| `video` | `<video controls>` |
| `audio` | `<audio controls>` + optional duration label |
| `file` | Download link with filename + size |

- Blob URL created via `URL.createObjectURL()`, revoked on unmount
- Remove button (absolute top-right) — only shown if `onRemove` is provided

---

## `Lightbox`

**File**: `src/components/Lightbox.tsx`  
**Used by**: `entry.$id.tsx`

### Props
```ts
{
  attachments: Attachment[];  // full attachment list (filters to images internally)
  startId: string;            // attachment id to open first
  onClose: () => void;
}
```

### What it does
- Full-screen image viewer (z-100, `bg-black/95`, `backdrop-blur-md`)
- Filters `attachments` to `kind === "image"` only
- Keyboard navigation: Escape=close, ArrowLeft/Right=prev/next
- Click outside image = close
- Download button (links to blob URL)
- `document.body.style.overflow = "hidden"` while open (restored on unmount)
- `touchAction: "pinch-zoom"` on image container for mobile zoom

---

## `CounterPanel`

**File**: `src/components/CounterPanel.tsx`  
**Used by**: `entry.$id.tsx`

### Props
```ts
{
  trips: Trip[];
  onChange: (next: Trip[]) => void;
}
```

### What it does
- Header: gradient background, shows total accepted + total rejected counts
- Accepted counter: stepper (−/+) + numeric input
- Rejected counter: stepper (−/+) + numeric input (red-accented)
- Quick-pick buttons: +4, +8, +10, +12 (sets accepted count, doesn't add — sets the value)
- Optional note input for the trip
- "Log trip" button → creates `Trip` object, calls `onChange`, resets inputs
- Trip history: reverse-chronological list with trip #, counts, time, note; delete button per trip

### State (local, not persisted until onChange called)
| State | Notes |
|---|---|
| `count` | Accepted count for the pending trip |
| `rejectedCount` | Rejected count for the pending trip |
| `note` | Note for the pending trip |

---

## `TagsInput`

**File**: `src/components/TagsInput.tsx`  
**Used by**: `entry.new.tsx`, `entry.$id.tsx`

### Props
```ts
{
  value: string[];
  onChange: (tags: string[]) => void;
  suggestions?: string[];
}
```

### Behaviour
- Tags displayed as pills with `×` remove button
- Input: Enter or `,` → adds tag; Backspace on empty input → removes last tag
- Tags are lowercased, `#` prefix stripped on input
- Suggestions: filtered to those not already selected and containing the current input; max 6 shown; tap to add
- Controlled component — no internal tag state

---

## `ui/` directory

shadcn/ui generated components (Radix UI primitives with CVA variants).  
These are standard shadcn components — refer to [shadcn/ui docs](https://ui.shadcn.com) for API.  
They are used sparingly in this project; most UI is custom-built directly.
