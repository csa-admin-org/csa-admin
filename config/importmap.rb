# frozen_string_literal: true

# Use direct uploads for Active Storage (remember to import "@rails/activestorage" in your application.js)
# pin "@rails/activestorage", to: "activestorage.esm.js"

# Use npm packages from a JavaScript CDN by running ./bin/importmap

pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin_all_from "app/javascript/components", under: "components"
pin "throttle-debounce" # @5.0.2

# AppSignal
pin "@appsignal/javascript", to: "@appsignal--javascript.js" # @1.6.1
pin "https", preload: false # @2.1.0
pin "tslib", preload: false # @2.8.1

# ActiveAdmin (used also by members)
pin "flowbite", to: "flowbite.turbo.min.js" # @3.1.2

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
pin "@joeattardi/emoji-button", to: "@joeattardi--emoji-button.js", preload: false # @4.6.4
pin "@roderickhsiao/emoji-button-locale-data/dist/de", to: "@roderickhsiao--emoji-button-locale-data--dist--de.js", preload: false
pin "@roderickhsiao/emoji-button-locale-data/dist/fr", to: "@roderickhsiao--emoji-button-locale-data--dist--fr.js", preload: false
pin "@roderickhsiao/emoji-button-locale-data/dist/it", to: "@roderickhsiao--emoji-button-locale-data--dist--it.js", preload: false
# Don't forget to update app/assets/stylesheets/tom-select.css too
pin "tom-select", preload: false # @2.3.1
pin "@stimulus-components/sortable", to: "@stimulus-components--sortable.js" # @5.0.3
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.12
pin "sortablejs" # @1.15.6
# Codemirror
pin "@codemirror/autocomplete", to: "@codemirror--autocomplete.js", preload: false # @6.19.1
pin "@codemirror/commands", to: "@codemirror--commands.js", preload: false # @6.10.0
pin "@codemirror/lang-yaml", to: "@codemirror--lang-yaml.js", preload: false # @6.1.2
pin "@codemirror/lang-liquid", to: "@codemirror--lang-liquid.js", preload: false # @6.3.0
pin "@codemirror/lang-css", to: "@codemirror--lang-css.js", preload: false # @6.3.1
pin "@codemirror/lang-html", to: "@codemirror--lang-html.js", preload: false # @6.4.11
pin "@codemirror/lang-javascript", to: "@codemirror--lang-javascript.js", preload: false # @6.2.4
pin "@codemirror/language", to: "@codemirror--language.js", preload: false # @6.11.3
pin "@codemirror/state", to: "@codemirror--state.js", preload: false # @6.5.2
pin "@codemirror/view", to: "@codemirror--view.js", preload: false # @6.38.8
pin "@lezer/common", to: "@lezer--common.js", preload: false # @1.3.0
pin "@lezer/css", to: "@lezer--css.js", preload: false # @1.3.0
pin "@lezer/highlight", to: "@lezer--highlight.js", preload: false # @1.2.3
pin "@lezer/html", to: "@lezer--html.js", preload: false # @1.3.12
pin "@lezer/javascript", to: "@lezer--javascript.js", preload: false # @1.5.4
pin "@lezer/lr", to: "@lezer--lr.js", preload: false # @1.4.3
pin "@lezer/yaml", to: "@lezer--yaml.js", preload: false # @1.0.3
pin "@marijn/find-cluster-break", to: "@marijn--find-cluster-break.js", preload: false # @1.0.2
pin "@fsegurai/codemirror-theme-github-dark", to: "@fsegurai--codemirror-theme-github-dark.js", preload: false # @6.2.2
pin "@fsegurai/codemirror-theme-github-light", to: "@fsegurai--codemirror-theme-github-light.js", preload: false # @6.2.2
pin "crelt", preload: false # @1.0.6
pin "style-mod", preload: false # @4.1.3
pin "w3c-keyname", preload: false # @2.2.8
# ActiveAdmin
pin "@rails/ujs", to: "@rails--ujs.js", preload: false # @7.1.3
pin_all_from File.join(`bundle show activeadmin`.strip, "app/javascript/active_admin"), under: "active_admin", preload: false
