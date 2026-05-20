export interface QuickTemplate {
  label: string;
  title: string;
  tags: string[];
  withCounter?: boolean;
}

export const QUICK_TEMPLATES: QuickTemplate[] = [
  { label: "Tyre count", title: "Tyre count – ", tags: ["tyres", "count"], withCounter: true },
  { label: "Tyre issue", title: "Tyre issue – ", tags: ["tyres", "urgent"] },
  { label: "Driver issue", title: "Driver – ", tags: ["driver"] },
  { label: "Invoice mismatch", title: "Invoice mismatch – ", tags: ["invoice"] },
  { label: "Missing stock", title: "Missing stock – ", tags: ["stock"] },
  { label: "Loading delay", title: "Loading delay – Bay ", tags: ["loading", "dispatch"] },
  { label: "Damage report", title: "Damage – ", tags: ["damage", "urgent"] },
];
