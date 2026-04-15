import { ChartTooltip, LineChart } from '@mantine/charts';
import {
  ActionIcon,
  Badge,
  Box,
  Button,
  Divider,
  Flex,
  Group,
  Paper,
  SimpleGrid,
  Stack,
  Table,
  Text,
  Title,
  useMantineColorScheme,
} from '@mantine/core';
import { useCallback, useEffect, useLayoutEffect, useMemo, useState } from 'react';
import type { CreditReport } from './creditUtils';
import {
  buildScoreTimeline,
  formatCurrencyInteger,
  formatDateTime,
  getCreditStatus,
  getParentResourceName,
} from './creditUtils';

const HISTORY_CHART_LIMIT = 10;

/** Served from `public/logo.png` (copied to `dist/` on build) */
const LOGO_SRC = `${import.meta.env.BASE_URL}logo.png`;

type NuiMessage = { action: 'open'; report: CreditReport } | { action: 'close' };

export type AppProps = {
  /** Passed from shell on first boot so the first paint is not "closed" under Mantine (FiveM CEF black frame). */
  initialOpenMessage?: Extract<NuiMessage, { action: 'open' }> | null;
};

function initialStateFromMessage(msg: AppProps['initialOpenMessage']) {
  if (msg?.action === 'open' && msg.report) {
    return { open: true as const, report: msg.report };
  }
  return { open: false as const, report: null as CreditReport | null };
}

function closeReportNui(): Promise<void> {
  return fetch(`https://${getParentResourceName()}/close`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
  })
    .then(() => undefined)
    .catch(() => undefined);
}

let reloadToShellScheduled = false;

/** Mantine + CEF leave composited black plates until styles are torn down; full reload returns to the thin shell (main.tsx). */
async function reloadNuiToShell(): Promise<void> {
  if (reloadToShellScheduled) return;
  reloadToShellScheduled = true;
  await closeReportNui();
  window.location.reload();
}

export function App({ initialOpenMessage = null }: AppProps) {
  const initial = useMemo(() => initialStateFromMessage(initialOpenMessage), [initialOpenMessage]);
  const [open, setOpen] = useState(initial.open);
  const [report, setReport] = useState<CreditReport | null>(initial.report);
  const { colorScheme, toggleColorScheme } = useMantineColorScheme();
  const isDark = colorScheme === 'dark';

  const handleClose = useCallback(() => {
    setOpen(false);
    setReport(null);
    void reloadNuiToShell();
  }, []);

  useEffect(() => {
    const onMessage = (event: MessageEvent<NuiMessage>) => {
      const data = event.data;
      if (!data || typeof data !== 'object') return;
      if (data.action === 'open' && data.report) {
        setReport(data.report);
        setOpen(true);
      } else if (data.action === 'close') {
        setOpen(false);
        setReport(null);
        void reloadNuiToShell();
      }
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, []);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') handleClose();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, handleClose]);

  /*
   * FiveM CEF: keep the *entire* document transparent while open. Mantine + dark `color-scheme`
   * can otherwise paint a full-frame black plate behind the centered Paper (even with no dimmer div).
   */
  useLayoutEffect(() => {
    if (!open) return;
    const html = document.documentElement;
    const body = document.body;
    const root = document.getElementById('root');
    const prev = {
      htmlBg: html.style.backgroundColor,
      bodyBg: body.style.backgroundColor,
      rootBg: root?.style.backgroundColor ?? '',
      colorScheme: html.style.colorScheme,
    };

    const style = document.createElement('style');
    style.id = 'bs-credit-open-transparency';
    style.textContent = `
      html, body, #root {
        background: transparent !important;
        background-color: transparent !important;
        background-image: none !important;
        min-height: 0 !important;
      }
      #root { height: auto !important; }
      html, body { color-scheme: normal !important; }
    `;
    document.head.appendChild(style);

    html.style.setProperty('background', 'transparent', 'important');
    html.style.setProperty('background-color', 'transparent', 'important');
    body.style.setProperty('background', 'transparent', 'important');
    body.style.setProperty('background-color', 'transparent', 'important');
    html.style.setProperty('color-scheme', 'normal', 'important');
    body.style.setProperty('color-scheme', 'normal', 'important');
    if (root) {
      root.style.setProperty('background', 'transparent', 'important');
      root.style.setProperty('background-color', 'transparent', 'important');
      root.style.setProperty('min-height', '0', 'important');
      root.style.setProperty('height', 'auto', 'important');
    }

    return () => {
      style.remove();
      html.style.backgroundColor = prev.htmlBg;
      html.style.removeProperty('background');
      html.style.removeProperty('background-color');
      html.style.colorScheme = prev.colorScheme;
      html.style.removeProperty('color-scheme');
      body.style.backgroundColor = prev.bodyBg;
      body.style.removeProperty('background');
      body.style.removeProperty('background-color');
      body.style.removeProperty('color-scheme');
      if (root) {
        root.style.backgroundColor = prev.rootBg;
        root.style.removeProperty('background');
        root.style.removeProperty('background-color');
        root.style.removeProperty('min-height');
        root.style.removeProperty('height');
      }
    };
  }, [open]);

  const chartData = useMemo(() => {
    if (!report) return [];
    return buildScoreTimeline(report.creditScore, report.creditHistory ?? [], HISTORY_CHART_LIMIT);
  }, [report]);

  const status = report ? getCreditStatus(report.creditScore) : null;

  if (!open || !report) {
    return null;
  }

  /*
   * No full-screen dimmer. Avoid translate(-50%,-50%): promoted layers + CEF often show black outside the card.
   * Center with calc() only.
   */
  return (
    <Paper
      shadow="none"
      radius="sm"
      withBorder
      mih={400}
      h="92vh"
      mah="92vh"
      styles={{ root: { boxShadow: 'none' } }}
      style={{
        position: 'fixed',
        top: 'calc((100vh - 92vh) / 2)',
        left: 'calc((100vw - min(880px, 94vw)) / 2)',
        width: 'min(880px, 94vw)',
        maxWidth: '94vw',
        zIndex: 1000,
        pointerEvents: 'auto',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
        willChange: 'auto',
      }}
    >
        <Box
          px="lg"
          py="md"
          style={{
            background: isDark
              ? 'linear-gradient(135deg, var(--mantine-color-dark-6) 0%, var(--mantine-color-dark-8) 100%)'
              : 'linear-gradient(135deg, var(--mantine-color-gray-1) 0%, var(--mantine-color-gray-3) 100%)',
            borderBottom: isDark ? '3px solid var(--mantine-color-red-7)' : '3px solid var(--mantine-color-red-6)',
          }}
        >
          <Group justify="space-between" wrap="nowrap">
            <Group gap="md" wrap="nowrap">
              <Box
                component="img"
                src={LOGO_SRC}
                alt="Maze Bank"
                w={50}
                h={50}
                style={{ objectFit: 'contain' }}
              />
              <Title
                order={2}
                c={isDark ? 'white' : 'dark.7'}
                style={{ textShadow: isDark ? '0 2px 4px rgba(0,0,0,0.45)' : 'none' }}
              >
                Credit Report
              </Title>
            </Group>
            <ActionIcon
              variant="subtle"
              color="gray"
              size="xl"
              radius="sm"
              aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
              onClick={() => toggleColorScheme()}
              styles={{
                root: {
                  color: isDark ? 'white' : 'var(--mantine-color-dark-7)',
                  border: isDark ? '2px solid rgba(255,255,255,0.35)' : '2px solid rgba(0,0,0,0.12)',
                  background: isDark ? 'rgba(0,0,0,0.25)' : 'rgba(255,255,255,0.65)',
                },
                icon: {
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  margin: 0,
                },
              }}
            >
              <Text component="span" fz={18} lh={1}>
                {isDark ? '☀' : '☾'}
              </Text>
            </ActionIcon>
          </Group>
        </Box>

        <Flex
          direction="column"
          gap="lg"
          p="lg"
          style={{ flex: 1, minHeight: 0, overflow: 'hidden' }}
        >
          <Stack gap="lg" style={{ flexShrink: 0 }}>
            <Box>
              <Text fw={700} size="sm" c="dimmed" tt="uppercase" mb="xs">
                Personal information
              </Text>
              <SimpleGrid cols={{ base: 1, sm: 2 }} spacing="sm">
                <InfoField label="First name" value={report.firstname} />
                <InfoField label="Last name" value={report.lastname} />
                <InfoField label="Date of birth" value={report.birthdate} />
                <InfoField label={report.idLabel ?? 'Citizen ID'} value={report.citizenid} />
                <InfoField label="Job" value={report.jobName} />
                <InfoField label="Job grade" value={report.jobGradeName} />
              </SimpleGrid>
            </Box>

            <Divider />

            <Box>
              <Text fw={700} size="sm" c="dimmed" tt="uppercase" mb="xs">
                Financial summary
              </Text>
              <SimpleGrid cols={{ base: 1, sm: 2 }} spacing="md">
                <Paper withBorder p="md" radius="sm" shadow="none">
                  <Text size="xs" c="dimmed" tt="uppercase" fw={600}>
                    Bank balance
                  </Text>
                  <Text fz="xl" fw={700} mt={4} c="var(--mantine-color-text)">
                    {formatCurrencyInteger(report.bankBalance)}
                  </Text>
                </Paper>
                <Paper withBorder p="md" radius="sm" shadow="none">
                  <Group justify="space-between" align="flex-start" wrap="nowrap">
                    <Box>
                      <Text size="xs" c="dimmed" tt="uppercase" fw={600}>
                        Credit score
                      </Text>
                      <Text fz="xl" fw={800} mt={4} c="var(--mantine-color-text)">
                        {report.creditScore}
                      </Text>
                    </Box>
                    {status && (
                      <Badge color={status.color} variant="light" size="lg" radius="sm">
                        {status.text}
                      </Badge>
                    )}
                  </Group>
                  <Text size="xs" c="dimmed" mt="xs">
                    Range 300–850
                  </Text>
                </Paper>
              </SimpleGrid>
            </Box>

            {chartData.length > 0 && (
              <Box>
                <Text fw={700} size="sm" c="dimmed" tt="uppercase" mb="xs">
                  Score trend (last {HISTORY_CHART_LIMIT} changes)
                </Text>
                <Text size="xs" c="dimmed" mb="sm">
                  Points show your score after each listed change, oldest to newest.
                </Text>
                <Box
                  style={{
                    backgroundColor: 'transparent',
                    // Inherit into Mantine charts (scoped color scheme can miss default chart theme selectors)
                    ['--chart-text-color' as string]: 'var(--mantine-color-text)',
                    ['--chart-grid-color' as string]: isDark
                      ? 'rgba(255,255,255,0.14)'
                      : 'rgba(0,0,0,0.12)',
                  }}
                >
                  <LineChart
                    h={240}
                    data={chartData}
                    dataKey="label"
                    series={[{ name: 'score', color: 'red.6', label: 'Credit score' }]}
                    curveType="monotone"
                    withDots
                    withLegend={false}
                    gridAxis="xy"
                    style={{ backgroundColor: 'transparent' }}
                    tooltipProps={{
                    content: ({ label, payload }) => (
                      <ChartTooltip
                        label={(payload?.[0]?.payload as { tooltip?: string })?.tooltip ?? label}
                        payload={payload}
                        series={[{ name: 'score', color: 'red.6', label: 'Credit score' }]}
                        valueFormatter={(value) => `${value}`}
                      />
                    ),
                  }}
                  />
                </Box>
              </Box>
            )}
          </Stack>

          <Flex direction="column" gap="xs" style={{ flex: 1, minHeight: 160, minWidth: 0 }}>
            <Text fw={700} size="sm" c="dimmed" tt="uppercase">
              Credit history
            </Text>
            {!report.creditHistory?.length ? (
              <Text c="dimmed" size="sm" style={{ flexShrink: 0 }}>
                No credit history available
              </Text>
            ) : (
              <Box
                className="bs-credit-history-scroll"
                style={{
                  flex: 1,
                  minHeight: 0,
                  minWidth: 0,
                  overflowY: 'auto',
                  overflowX: 'hidden',
                  WebkitOverflowScrolling: 'touch',
                }}
              >
                <Table striped highlightOnHover withTableBorder withColumnBorders>
                  <Table.Thead>
                    <Table.Tr>
                      <Table.Th>Change</Table.Th>
                      <Table.Th>Description</Table.Th>
                      <Table.Th>Date</Table.Th>
                    </Table.Tr>
                  </Table.Thead>
                  <Table.Tbody>
                    {report.creditHistory.map((entry, idx) => {
                      const change = Number(entry.change_amount) || 0;
                      const positive = change > 0;
                      return (
                        <Table.Tr key={`${entry.created_at}-${idx}`}>
                          <Table.Td>
                            <Text component="span" fw={600} c={positive ? 'green' : 'red'}>
                              {positive ? `+${change}` : change} pts
                            </Text>
                          </Table.Td>
                          <Table.Td>
                            <Text component="span" size="sm" c="var(--mantine-color-text)">
                              {entry.description ?? '—'}
                            </Text>
                          </Table.Td>
                          <Table.Td>
                            <Text component="span" size="sm" c="var(--mantine-color-text)">
                              {formatDateTime(entry.created_at)}
                            </Text>
                          </Table.Td>
                        </Table.Tr>
                      );
                    })}
                  </Table.Tbody>
                </Table>
              </Box>
            )}
          </Flex>

          <Button fullWidth variant="light" color="gray" onClick={handleClose} style={{ flexShrink: 0 }}>
            Close
          </Button>
        </Flex>
    </Paper>
  );
}

function InfoField({ label, value }: { label: string; value: string }) {
  return (
    <Paper withBorder p="sm" radius="sm" shadow="none">
      <Text size="xs" c="dimmed" tt="uppercase" fw={600}>
        {label}
      </Text>
      <Text size="sm" fw={500} mt={4} c="var(--mantine-color-text)">
        {value || '—'}
      </Text>
    </Paper>
  );
}
