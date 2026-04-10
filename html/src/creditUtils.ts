export type CreditHistoryEntry = {
  change_amount: number;
  description: string | null;
  created_at: string;
};

export type CreditReport = {
  citizenid: string;
  idLabel?: string;
  firstname: string;
  lastname: string;
  birthdate: string;
  jobName: string;
  jobGradeName: string;
  bankBalance: number;
  creditScore: number;
  creditHistory: CreditHistoryEntry[];
};

export function formatCurrencyInteger(amount: number): string {
  const n = Math.floor(Number(amount) || 0);
  return `$${n.toLocaleString()}`;
}

export function formatDateTime(dateString: string | null | undefined): string {
  if (!dateString || dateString === 'Unknown') return 'Unknown';
  try {
    const date = new Date(dateString);
    if (Number.isNaN(date.getTime())) return dateString;
    return date.toLocaleString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return dateString;
  }
}

export function getCreditStatus(score: number): { text: string; color: string } {
  if (score >= 781) return { text: 'Excellent', color: 'green' };
  if (score >= 661) return { text: 'Good', color: 'teal' };
  if (score >= 601) return { text: 'Fair', color: 'yellow' };
  if (score >= 500) return { text: 'Poor', color: 'orange' };
  return { text: 'Very Poor', color: 'red' };
}

/** History from API is newest-first. Reconstructs score after each of the last `limit` events (oldest → newest on the chart). */
export function buildScoreTimeline(
  currentScore: number,
  historyNewestFirst: CreditHistoryEntry[],
  limit = 10
): { label: string; score: number; tooltip: string }[] {
  const slice = historyNewestFirst.slice(0, limit);
  if (slice.length === 0) return [];

  const chronological = [...slice].reverse();
  const sumDelta = slice.reduce((acc, e) => acc + (Number(e.change_amount) || 0), 0);
  let running = currentScore - sumDelta;

  return chronological.map((entry, idx) => {
    const change = Number(entry.change_amount) || 0;
    running += change;
    return {
      label: formatChartAxisLabel(entry.created_at, idx),
      score: Math.round(running),
      tooltip: formatDateTime(entry.created_at),
    };
  });
}

function formatChartAxisLabel(createdAt: string, index: number): string {
  try {
    const date = new Date(createdAt);
    if (Number.isNaN(date.getTime())) return `#${index + 1}`;
    const short = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    return `${short} (${index + 1})`;
  } catch {
    return `#${index + 1}`;
  }
}

export function getParentResourceName(): string {
  const path = window.location.pathname;
  const match = path.match(/\/([^/]+)\/html\//);
  if (match) return match[1];
  try {
    const scripts = document.getElementsByTagName('script');
    for (let i = 0; i < scripts.length; i++) {
      const src = scripts[i].src;
      if (src.includes('/assets/') && src.includes('index')) {
        const urlMatch = src.match(/https?:\/\/cfx-nui-([^/]+)\//);
        if (urlMatch) return urlMatch[1];
      }
    }
  } catch {
    /* ignore */
  }
  return 'bs_credit';
}
