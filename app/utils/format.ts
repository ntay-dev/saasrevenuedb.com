import { format } from "date-fns";
import { enUS } from "date-fns/locale";

export function formatCurrency(
  value: number | bigint | null | undefined,
  currency = "USD",
): string {
  if (value == null) return "—";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(Number(value));
}

export function formatCompact(
  value: number | bigint | null | undefined,
): string {
  if (value == null) return "—";
  return new Intl.NumberFormat("en-US", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(Number(value));
}

export function formatNumber(
  value: number | bigint | null | undefined,
  locale = "en-US",
): string {
  if (value == null) return "—";
  return Number(value).toLocaleString(locale);
}

export function formatPercent(value: number | null | undefined): string {
  if (value == null) return "—";
  const sign = value >= 0 ? "+" : "";
  return `${sign}${value}%`;
}

export function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "—";
  return format(new Date(dateStr), "MMM dd, yyyy", { locale: enUS });
}

export function formatDateShort(dateStr: string | null | undefined): string {
  if (!dateStr) return "—";
  return format(new Date(dateStr), "MMM yyyy", { locale: enUS });
}
