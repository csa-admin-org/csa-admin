# frozen_string_literal: true


# Use npm packages from a JavaScript CDN by running ./bin/importmap

pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin_all_from "app/javascript/components", under: "components"
pin "throttle-debounce" # @5.0.2

# AppSignal
pin "@appsignal/javascript", to: "@appsignal--javascript.js" # @1.6.1
pin "https", preload: false # @2.1.0
pin "tslib", preload: false # @2.8.1

# ActiveAdmin (used also by members)
pin "flowbite", to: "flowbite.turbo.min.js" # @4.0.1

# Members
pin "members", preload: false
pin_all_from "app/javascript/controllers/members", under: "controllers/members", preload: false
pin "flatpickr", preload: false # @4.6.13
pin "flatpickr/dist/l10n/fr", to: "flatpickr--dist--l10n--fr.js", preload: false
pin "flatpickr/dist/l10n/de", to: "flatpickr--dist--l10n--de.js", preload: false
pin "flatpickr/dist/l10n/it", to: "flatpickr--dist--l10n--it.js", preload: false

# Admin
pin "admin", preload: false
pin_all_from "app/javascript/admin", under: "admin", preload: false
pin_all_from "app/javascript/controllers/admin", under: "controllers/admin", preload: false
pin "trix", to: "trix.js", preload: false
pin "@rails/actiontext", to: "actiontext.js", preload: false
# Emoji-Button
pin "@joeattardi/emoji-button", to: "@joeattardi--emoji-button.js", preload: false # @4.6.4
pin "@roderickhsiao/emoji-button-locale-data/dist/de", to: "@roderickhsiao--emoji-button-locale-data--dist--de.js", preload: false
pin "@roderickhsiao/emoji-button-locale-data/dist/fr", to: "@roderickhsiao--emoji-button-locale-data--dist--fr.js", preload: false
pin "@roderickhsiao/emoji-button-locale-data/dist/it", to: "@roderickhsiao--emoji-button-locale-data--dist--it.js", preload: false
# Sortable
pin "@stimulus-components/sortable", to: "@stimulus-components--sortable.js" # @5.0.3
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.13
pin "sortablejs" # @1.15.6
# CodeJar + Prism.js
pin "codejar", preload: false # @4.3.0
pin "prismjs", preload: false # @1.30.0
pin "prismjs/components/prism-yaml", to: "prismjs--components--prism-yaml.js", preload: false
pin "prismjs/components/prism-markup-templating", to: "prismjs--components--prism-markup-templating.js", preload: false
pin "prismjs/components/prism-liquid", to: "prismjs--components--prism-liquid.js", preload: false
# ActiveAdmin
pin "@rails/ujs", to: "@rails--ujs.js", preload: false # @7.1.3
pin_all_from File.join(`bundle show activeadmin`.strip, "app/javascript/active_admin"), under: "active_admin", preload: false
