# Use direct uploads for Active Storage (remember to import "@rails/activestorage" in your application.js)
# pin "@rails/activestorage", to: "activestorage.esm.js"

# Use npm packages from a JavaScript CDN by running ./bin/importmap

pin "trix", to: "trix.js"
pin "@rails/actiontext", to: "actiontext.js"

pin "@hotwired/stimulus", to: "stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/components", under: "components"
pin "throttle-debounce" # @5.0.0

pin "members"
pin "@hotwired/turbo-rails", to: "turbo.js"
pin_all_from "app/javascript/controllers/members", under: "controllers/members"
pin "flatpickr" # @4.6.13
pin "flatpickr/dist/l10n/fr", to: "flatpickr--dist--l10n--fr.js" # @4.6.13
pin "flatpickr/dist/l10n/de", to: "flatpickr--dist--l10n--de.js" # @4.6.13
pin "flatpickr/dist/l10n/it", to: "flatpickr--dist--l10n--it.js" # @4.6.13

pin "admin"
pin_all_from "app/javascript/controllers/admin", under: "controllers/admin"
pin "@joeattardi/emoji-button", to: "@joeattardi--emoji-button.js" # @4.6.4
pin "@roderickhsiao/emoji-button-locale-data/dist/de", to: "@roderickhsiao--emoji-button-locale-data--dist--de.js" # @0.1.2
pin "@roderickhsiao/emoji-button-locale-data/dist/fr", to: "@roderickhsiao--emoji-button-locale-data--dist--fr.js" # @0.1.2
pin "@roderickhsiao/emoji-button-locale-data/dist/it", to: "@roderickhsiao--emoji-button-locale-data--dist--it.js" # @0.1.2
pin "ace-builds" # @1.9.6
pin "ace-builds/src-noconflict/mode-liquid", to: "ace-builds--src-noconflict--mode-liquid.js" # @1.9.6
pin "ace-builds/src-noconflict/mode-yaml", to: "ace-builds--src-noconflict--mode-yaml.js" # @1.9.6
pin "ace-builds/src-noconflict/theme-dreamweaver", to: "ace-builds--src-noconflict--theme-dreamweaver.js" # @1.9.6
# Don't forget to update vendor/assets/stylesheets/tom-select/dist/css/tom-select.css too
pin "tom-select" # @2.1.0

# Sentry
pin "@sentry/browser", to: "https://ga.jspm.io/npm:@sentry/browser@7.51.0/esm/index.js"
pin "@sentry/core", to: "https://ga.jspm.io/npm:@sentry/core@7.51.0/esm/index.js"
pin "@sentry/replay", to: "https://ga.jspm.io/npm:@sentry/replay@7.51.0/esm/index.js"
pin "@sentry/utils", to: "https://ga.jspm.io/npm:@sentry/utils@7.51.0/esm/index.js"
pin "@sentry-internal/tracing", to: "https://ga.jspm.io/npm:@sentry-internal/tracing@7.51.0/esm/index.js"
pin "@sentry/utils/esm/buildPolyfills", to: "https://ga.jspm.io/npm:@sentry/utils@7.51.0/esm/buildPolyfills/index.js"
