/**
 * Thin FiveM NUI entry: no Mantine/React until the first credit report `open`
 * message, so this resource does not paint a full-viewport layer over the game
 * while idle (other resources' UIs stack above us).
 */
import './shell.css';

const openQueue: unknown[] = [];
let bootPromise: Promise<void> | null = null;
let booted = false;

window.addEventListener('message', function onMessage(e: MessageEvent) {
  if (booted) return;

  const data = e.data;
  if (!data || typeof data !== 'object') return;
  if ((data as { action?: string }).action !== 'open') return;

  openQueue.push(data);

  if (!bootPromise) {
    bootPromise = import('./creditApp')
      .then(({ mountCreditUi }) => {
        const batch = openQueue.splice(0, openQueue.length);
        const lastOpen = [...batch]
          .reverse()
          .find(
            (d) =>
              d &&
              typeof d === 'object' &&
              (d as { action?: string }).action === 'open' &&
              (d as { report?: unknown }).report,
          );
        booted = true;
        window.removeEventListener('message', onMessage);
        mountCreditUi(lastOpen ?? null);
        /* Re-dispatch so any listeners still see the same sequence; first paint already has data from initialOpenMessage. */
        requestAnimationFrame(() => {
          for (const data of batch) {
            window.dispatchEvent(new MessageEvent('message', { data }));
          }
        });
      })
      .catch(() => {
        bootPromise = null;
      });
  }
});
