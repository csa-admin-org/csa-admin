import browserUpdate from 'browser-update';

browserUpdate({
  required: { e: -4, f: -3, o: -3, s: -1, c: -3 },
  insecure: true,
  notify_esr: true,
  style: 'bottom',
  reminderClosed: 240,
  api: 2024.08,
})
