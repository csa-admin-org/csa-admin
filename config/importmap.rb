# Use direct uploads for Active Storage (remember to import "@rails/activestorage" in your application.js)
# pin "@rails/activestorage", to: "activestorage.esm.js"

# Use npm packages from a JavaScript CDN by running ./bin/importmap

pin "members"
pin "@hotwired/turbo-rails", to: "turbo.js"
pin "@hotwired/stimulus", to: "stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/components", under: "components"
pin "flatpickr", to: "https://ga.jspm.io/npm:flatpickr@4.6.9/dist/flatpickr.js"
pin "flatpickr/dist/l10n/fr", to: "https://ga.jspm.io/npm:flatpickr@4.6.9/dist/l10n/fr.js"
pin "flatpickr/dist/l10n/it", to: "https://ga.jspm.io/npm:flatpickr@4.6.9/dist/l10n/it.js"
pin "flatpickr/dist/l10n/de", to: "https://ga.jspm.io/npm:flatpickr@4.6.9/dist/l10n/de.js"
