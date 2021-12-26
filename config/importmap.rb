# Use direct uploads for Active Storage (remember to import "@rails/activestorage" in your application.js)
# pin "@rails/activestorage", to: "activestorage.esm.js"

# Use npm packages from a JavaScript CDN by running ./bin/importmap

# TODO: Change when on Rails 7, instead of using the component version
# pin "trix"
# pin "@rails/actiontext", to: "actiontext.js"

pin "@hotwired/stimulus", to: "stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/components", under: "components"

pin "members"
pin "@hotwired/turbo-rails", to: "turbo.js"
pin_all_from "app/javascript/controllers/members", under: "controllers/members"
pin "lodash/debounce", to: "https://ga.jspm.io/npm:lodash@4.17.21/debounce.js"
pin "flatpickr", to: "https://ga.jspm.io/npm:flatpickr@4.6.9/dist/flatpickr.js"
pin "flatpickr/dist/l10n/fr", to: "https://ga.jspm.io/npm:flatpickr@4.6.9/dist/l10n/fr.js"
pin "flatpickr/dist/l10n/it", to: "https://ga.jspm.io/npm:flatpickr@4.6.9/dist/l10n/it.js"
pin "flatpickr/dist/l10n/de", to: "https://ga.jspm.io/npm:flatpickr@4.6.9/dist/l10n/de.js"

pin "admin"
pin_all_from "app/javascript/controllers/admin", under: "controllers/admin"
pin "emoji-button", to: "https://cdn.jsdelivr.net/npm/@joeattardi/emoji-button@4.6.2/dist/index.min.js"
pin "@roderickhsiao/emoji-button-locale-data/dist/de", to: "https://cdn.jsdelivr.net/npm/@roderickhsiao/emoji-button-locale-data@0.1.2/dist/de.js"
pin "@roderickhsiao/emoji-button-locale-data/dist/fr", to: "https://cdn.jsdelivr.net/npm/@roderickhsiao/emoji-button-locale-data@0.1.2/dist/fr.js"
pin "@roderickhsiao/emoji-button-locale-data/dist/it", to: "https://cdn.jsdelivr.net/npm/@roderickhsiao/emoji-button-locale-data@0.1.2/dist/it.js"
