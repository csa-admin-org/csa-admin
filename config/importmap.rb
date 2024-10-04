# frozen_string_literal: true

# Use direct uploads for Active Storage (remember to import "@rails/activestorage" in your application.js)
# pin "@rails/activestorage", to: "activestorage.esm.js"

# Use npm packages from a JavaScript CDN by running ./bin/importmap

pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin_all_from "app/javascript/components", under: "components"
pin "throttle-debounce" # @5.0.2

# ActiveAdmin (used also by members)
pin "flowbite", to: "flowbite.turbo.min.js" # @2.4.1
pin "browser-update" # @3.3.54

# Members
pin "members", preload: false
pin_all_from "app/javascript/controllers/members", under: "controllers/members", preload: false
pin "flatpickr", preload: false # @4.6.13
pin "flatpickr/dist/l10n/fr", to: "flatpickr--dist--l10n--fr.js", preload: false # @4.6.13
pin "flatpickr/dist/l10n/de", to: "flatpickr--dist--l10n--de.js", preload: false # @4.6.13
pin "flatpickr/dist/l10n/it", to: "flatpickr--dist--l10n--it.js", preload: false # @4.6.13

# Admin
pin "admin", preload: false
pin_all_from "app/javascript/admin", under: "admin", preload: false
pin_all_from "app/javascript/controllers/admin", under: "controllers/admin", preload: false
pin "trix", to: "trix.js", preload: false
pin "@rails/actiontext", to: "actiontext.js", preload: false
pin "@joeattardi/emoji-button", to: "@joeattardi--emoji-button.js", preload: false # @4.6.4
pin "@roderickhsiao/emoji-button-locale-data/dist/de", to: "@roderickhsiao--emoji-button-locale-data--dist--de.js", preload: false # @0.1.2
pin "@roderickhsiao/emoji-button-locale-data/dist/fr", to: "@roderickhsiao--emoji-button-locale-data--dist--fr.js", preload: false # @0.1.2
pin "@roderickhsiao/emoji-button-locale-data/dist/it", to: "@roderickhsiao--emoji-button-locale-data--dist--it.js", preload: false # @0.1.2
pin "ace-builds", preload: false # @1.36.2
pin "ace-builds/src-noconflict/mode-liquid", to: "ace-builds--src-noconflict--mode-liquid.js", preload: false # @1.36.2
pin "ace-builds/src-noconflict/mode-yaml", to: "ace-builds--src-noconflict--mode-yaml.js", preload: false # @1.36.2
pin "ace-builds/src-noconflict/theme-textmate", to: "ace-builds--src-noconflict--theme-textmate.js", preload: false # @1.36.2
# Don't forget to update app/assets/stylesheets/tom-select.css too
pin "tom-select", preload: false # @2.3.1
pin "@stimulus-components/sortable", to: "@stimulus-components--sortable.js", preload: false # @5.0.1
pin "@rails/request.js", to: "@rails--request.js.js", preload: false # @0.0.11
pin "sortablejs", preload: false # @1.15.3
# ActiveAdmin
pin "@rails/ujs", to: "@rails--ujs.js", preload: false # @7.1.3
pin_all_from File.join(`bundle show activeadmin`.strip, "app/javascript/active_admin"), under: "active_admin", preload: false
