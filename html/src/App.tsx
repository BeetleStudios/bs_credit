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
import { useCallback, useEffect, useMemo, useState } from 'react';
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

function closeReport() {
  fetch(`https://${getParentResourceName()}/close`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
  });
}

export function App() {
  const [open, setOpen] = useState(false);
  const [report, setReport] = useState<CreditReport | null>(null);
  const { colorScheme, toggleColorScheme } = useMantineColorScheme();
  const isDark = colorScheme === 'dark';

  const handleClose = useCallback(() => {
    setOpen(false);
    setReport(null);
    closeReport();
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

  const chartData = useMemo(() => {
    if (!report) return [];
    return buildScoreTimeline(report.creditScore, report.creditHistory ?? [], HISTORY_CHART_LIMIT);
  }, [report]);

  const status = report ? getCreditStatus(report.creditScore) : null;

  if (!open || !report) {
    return null;
  }

  return (
    <Box
      style={{
        position: 'fixed',
        inset: 0,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        pointerEvents: 'auto',
        background: 'rgba(0, 0, 0, 0.35)',
        zIndex: 1000,
      }}
    >
      <Paper
        shadow="xl"
        radius="sm"
        withBorder
        w={880}
        maw="94vw"
        mih={400}
        h="92vh"
        mah="92vh"
        style={{
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
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
                style={{ objectFit: 'contain', filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.35))' }}
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
                <Paper withBorder p="md" radius="sm">
                  <Text size="xs" c="dimmed" tt="uppercase" fw={600}>
                    Bank balance
                  </Text>
                  <Text fz="xl" fw={700} mt={4} c="var(--mantine-color-text)">
                    {formatCurrencyInteger(report.bankBalance)}
                  </Text>
                </Paper>
                <Paper withBorder p="md" radius="sm">
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
    </Box>
  );
}

function InfoField({ label, value }: { label: string; value: string }) {
  return (
    <Paper withBorder p="sm" radius="sm">
      <Text size="xs" c="dimmed" tt="uppercase" fw={600}>
        {label}
      </Text>
      <Text size="sm" fw={500} mt={4} c="var(--mantine-color-text)">
        {value || '—'}
      </Text>
    </Paper>
  );
}
