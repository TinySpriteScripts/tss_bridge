export type ThemeTokens = {
  name: string;
  styleVariant?: "classic" | "modern-glass" | "modern-slate" | "studio";
  graphVariant?: "line_graph" | "pie_chart";
  shell: string;
  shellInset: string;
  titleFrom: string;
  titleTo: string;
  titleText: string;
  accent: string;
  accentSoft: string;
  accentStrong: string;
  text: string;
  muted: string;
  borderLight: string;
  borderDark: string;
  panel: string;
  panelAlt: string;
  field: string;
  fieldText: string;
  success: string;
  danger: string;
  warning: string;
  overlay: string;
  chartA: string;
  chartB: string;
  chartC: string;
  chartD: string;
  chartE: string;
};

export type UIProps<Node, ButtonProps, TableProps> = {
  Shell: {
    title: string;
    activePage: string;
    onPageChange(id: string): void;
    onClose(): void;
    pages: Array<{ id: string; label: string; badge?: string; render(): Node }>;
    summary?: Array<{ label: string; value: string }>;
    children?: Node;
  };
  Panel: { title: string; className?: string; action?: Node; children?: Node };
  SectionHeader: { title: string; subtitle?: string; action?: Node };
  Chart: {
    variant: "line_graph" | "pie_chart";
    data: Array<{ label: string; value: number; color: string }>;
    formatValue(value: number): string;
    label?: string;
    emptyMessage?: string;
  };
  InfoCard: { label: string; value: string };
  Metric: { label: string; value: string; detail: string; tone?: "positive" | "negative" };
  TerminalIdle: { title: string; subtitle: string; instruction: string; footer: string };
  ConfirmDialog: {
    title: string;
    message: Node;
    confirmLabel: string;
    danger?: boolean;
    onCancel(): void;
    onConfirm(): void;
  };
  Button: ButtonProps & { variant?: "primary" | "secondary" | "danger" };
  Table: TableProps;
  Pill: { className?: string; children?: Node };
};
