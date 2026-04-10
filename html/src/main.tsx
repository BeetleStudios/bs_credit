import '@mantine/core/styles.css';
import '@mantine/charts/styles.css';
import { MantineProvider, createTheme, localStorageColorSchemeManager } from '@mantine/core';
import React from 'react';
import ReactDOM from 'react-dom/client';
import { App } from './App';
import './index.css';

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

const colorSchemeManager = localStorageColorSchemeManager({
  key: 'bs-credit-color-scheme',
});

const MANTINE_SCOPE_ID = 'bs-credit-mantine-scope';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <div
      id={MANTINE_SCOPE_ID}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'transparent',
        pointerEvents: 'none',
      }}
    >
      <MantineProvider
        theme={theme}
        defaultColorScheme="light"
        colorSchemeManager={colorSchemeManager}
        getRootElement={() => document.getElementById(MANTINE_SCOPE_ID) ?? undefined}
        cssVariablesSelector={`#${MANTINE_SCOPE_ID}`}
      >
        <App />
      </MantineProvider>
    </div>
  </React.StrictMode>
);
