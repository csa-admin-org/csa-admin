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
pin "throttle-debounce" # @3.0.1
pin "flatpickr" # @4.6.9
pin "flatpickr/dist/l10n/fr", to: "flatpickr--dist--l10n--fr.js" # @4.6.9
pin "flatpickr/dist/l10n/it", to: "flatpickr--dist--l10n--it.js" # @4.6.9
pin "flatpickr/dist/l10n/de", to: "flatpickr--dist--l10n--de.js" # @4.6.9

pin "admin"
pin_all_from "app/javascript/controllers/admin", under: "controllers/admin"
pin "@joeattardi/emoji-button", to: '@joeattardi--emoji-button.js' # @4.6.2/
pin "@roderickhsiao/emoji-button-locale-data/dist/de", to: "@roderickhsiao--emoji-button-locale-data--dist--de.js" # @0.1.2
pin "@roderickhsiao/emoji-button-locale-data/dist/fr", to: "@roderickhsiao--emoji-button-locale-data--dist--fr.js" # @0.1.2
pin "@roderickhsiao/emoji-button-locale-data/dist/it", to: "@roderickhsiao--emoji-button-locale-data--dist--it.js" # @0.1.2
