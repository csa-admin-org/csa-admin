import * as Sentry from "@sentry/browser";

Sentry.init({
  dsn: "https://98d2ed9e0cb845cabc1fff00323e06ca@o555399.ingest.sentry.io/5685152",
  environment: "production",
  tracesSampleRate: 0.05,
  debug: true
});
