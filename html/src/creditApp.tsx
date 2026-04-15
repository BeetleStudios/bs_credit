/* Heavy UI: only loaded after the first `open` NUI message (see main.tsx). */
import '@mantine/core/styles.layer.css';
import '@mantine/charts/styles.layer.css';
import {
  MantineProvider,
  createTheme,
  localStorageColorSchemeManager,
  type CSSVariablesResolver,
} from '@mantine/core';
import React from 'react';
import ReactDOM from 'react-dom/client';
import { App, type AppProps } from './App';
import './index.css';
import type { CreditReport } from './creditUtils';

const theme = createTheme({
  primaryColor: 'red',
  defaultRadius: 'sm',
  components: {
    Table: {
      styles: {
        td: { color: 'var(--mantine-color-text)' },
        th: { color: 'var(--mantine-color-dimmed)' },
      },
    },
  },
});

const creditNuiCssVariablesResolver: CSSVariablesResolver = () => ({
  variables: {
    '--mantine-color-body': 'transparent',
  },
  light: {},
  dark: {},
});

const colorSchemeManager = localStorageColorSchemeManager({
  key: 'bs-credit-color-scheme',
});

const MANTINE_SCOPE_ID = 'bs-credit-mantine-scope';

let root: ReactDOM.Root | null = null;

function asInitialOpenMessage(data: unknown): AppProps['initialOpenMessage'] {
  if (!data || typeof data !== 'object') return null;
  const o = data as { action?: string; report?: CreditReport };
  if (o.action === 'open' && o.report) {
    return { action: 'open', report: o.report };
  }
  return null;
}

export function mountCreditUi(firstOpenPayload: unknown): void {
  const host = document.getElementById('root');
  if (!host || root) return;

  const initialOpenMessage = asInitialOpenMessage(firstOpenPayload);

  root = ReactDOM.createRoot(host);
  root.render(
    <React.StrictMode>
      <div
        id={MANTINE_SCOPE_ID}
        style={{
          background: 'transparent',
          backgroundColor: 'transparent',
          minHeight: 0,
          height: 'auto',
        }}
      >
        <MantineProvider
          theme={theme}
          defaultColorScheme="light"
          colorSchemeManager={colorSchemeManager}
          getRootElement={() => document.getElementById(MANTINE_SCOPE_ID) ?? undefined}
          cssVariablesSelector={`#${MANTINE_SCOPE_ID}`}
          cssVariablesResolver={creditNuiCssVariablesResolver}
        >
          <App initialOpenMessage={initialOpenMessage} />
        </MantineProvider>
      </div>
    </React.StrictMode>
  );
}
