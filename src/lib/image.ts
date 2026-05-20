// Downscale a camera image to a sensible max edge before we persist it.
// Cuts memory pressure dramatically (a 12 MP JPEG can be ~6 MB; this brings
// it down to ~300-500 KB without losing diagnostic detail).

const MAX_EDGE = 1800;
const QUALITY = 0.85;

export async function downscaleImage(file: File | Blob, name?: string): Promise<Blob> {
  // Tiny files don't need work
  if (file.size < 600 * 1024) return file;

  let bitmap: ImageBitmap | null = null;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    // Fallback: just return original if decode fails
    return file;
  }

  const { width, height } = bitmap;
  const scale = Math.min(1, MAX_EDGE / Math.max(width, height));
  const w = Math.round(width * scale);
  const h = Math.round(height * scale);

  // Use OffscreenCanvas where possible to avoid main-thread layout work.
  let blob: Blob | null = null;
  try {
    if (typeof OffscreenCanvas !== "undefined") {
      const c = new OffscreenCanvas(w, h);
      const ctx = c.getContext("2d");
      if (!ctx) throw new Error("no 2d");
      ctx.drawImage(bitmap, 0, 0, w, h);
      blob = await c.convertToBlob({ type: "image/jpeg", quality: QUALITY });
    } else {
      const c = document.createElement("canvas");
      c.width = w;
      c.height = h;
      const ctx = c.getContext("2d");
      if (!ctx) throw new Error("no 2d");
      ctx.drawImage(bitmap, 0, 0, w, h);
      blob = await new Promise<Blob | null>((res) =>
        c.toBlob((b) => res(b), "image/jpeg", QUALITY),
      );
    }
  } finally {
    bitmap.close?.();
  }

  if (!blob) return file;

  // If the "compressed" version is somehow larger, keep the original.
  if (blob.size >= file.size) return file;
  return new File([blob], name ?? "photo.jpg", { type: "image/jpeg" });
}

export async function getImageDimensions(blob: Blob): Promise<{ width: number; height: number } | null> {
  try {
    const bmp = await createImageBitmap(blob);
    const out = { width: bmp.width, height: bmp.height };
    bmp.close?.();
    return out;
  } catch {
    return null;
  }
}
