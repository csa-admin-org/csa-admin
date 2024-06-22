# frozen_string_literal: true

# Use direct uploads for Active Storage (remember to import "@rails/activestorage" in your application.js)
# pin "@rails/activestorage", to: "activestorage.esm.js"

# Use npm packages from a JavaScript CDN by running ./bin/importmap

pin "trix", to: "trix.js"
pin "@rails/actiontext", to: "actiontext.js"

pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/components", under: "components"
pin "throttle-debounce" # @5.0.0

pin "members"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
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
pin "ace-builds/src-noconflict/theme-terminal", to: "ace-builds--src-noconflict--theme-terminal.js" # @1.35.0
# Don't forget to update app/assets/stylesheets/tom-select.css too
pin "tom-select" # @2.1.0
pin "stimulus-sortable", to: "https://ga.jspm.io/npm:stimulus-sortable@4.1.1/dist/stimulus-sortable.mjs"
pin "@rails/request.js", to: "https://ga.jspm.io/npm:@rails/request.js@0.0.9/src/index.js"
pin "sortablejs", to: "https://ga.jspm.io/npm:sortablejs@1.15.1/modular/sortable.esm.js"

# ActiveAdmin
pin "flowbite", to: "https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.turbo.min.js"
pin "@rails/ujs", to: "@rails--ujs.js" # @7.0.8
pin_all_from File.join(`bundle show activeadmin`.strip, "app/javascript/active_admin"), under: "active_admin"
