# frozen_string_literal: true


# Use npm packages from a JavaScript CDN by running ./bin/importmap

pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"

pin_all_from "app/javascript/components", under: "components"
pin "throttle-debounce" # @5.0.2

cap_api_url = ENV.fetch("CAP_API_URL", "https://cap.csa-admin.org").delete_suffix("/")
pin "cap-widget", to: "#{cap_api_url}/assets/widget.js", preload: false

# AppSignal
pin "@appsignal/javascript", to: "@appsignal--javascript.js" # @1.6.1
pin "https", preload: false # @2.1.0
pin "tslib", preload: false # @2.8.1

# Members
pin "members", preload: false
pin_all_from "app/javascript/controllers/members", under: "controllers/members", preload: false
# Pinned from unpkg (`bin/importmap pin vanilla-calendar-pro@3.3.1 --from unpkg`)
# because jspm still serves 3.2.0.
pin "vanilla-calendar-pro", preload: false # @3.3.2

# Admin
pin "admin", preload: false
pin_all_from "app/javascript/admin", under: "admin", preload: false
pin_all_from "app/javascript/controllers/admin", under: "controllers/admin", preload: false
pin "trix", to: "trix.js", preload: false
pin "@rails/actiontext", to: "actiontext.js", preload: false
# Sortable
pin "@stimulus-components/sortable", to: "@stimulus-components--sortable.js" # @5.0.3
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.13
pin "sortablejs" # @1.15.7
# CodeJar + Prism.js
pin "codejar", preload: false # @4.3.0
pin "prismjs", preload: false # @1.30.0
pin "prismjs/components/prism-yaml", to: "prismjs--components--prism-yaml.js", preload: false
pin "prismjs/components/prism-markup-templating", to: "prismjs--components--prism-markup-templating.js", preload: false
pin "prismjs/components/prism-liquid", to: "prismjs--components--prism-liquid.js", preload: false
pin "codejar-linenumbers", preload: false # @1.0.1
# ActiveAdmin
pin "@rails/ujs", to: "@rails--ujs.js", preload: false # @7.1.3
pin_all_from File.join(`bundle show activeadmin`.strip, "app/javascript/active_admin"), under: "active_admin", preload: false
# Floating UI (tooltip/popover positioning).
# Pinned from unpkg (`bin/importmap pin "@floating-ui/dom@VERSION" --from unpkg`)
# because jspm currently 404s on @floating-ui/core@1.8.x.
pin "@floating-ui/dom", to: "@floating-ui--dom.js", preload: false # @1.8.0
pin "@floating-ui/core", to: "@floating-ui--core.js", preload: false # @1.8.0
pin "@floating-ui/utils", to: "@floating-ui--utils.js", preload: false # @0.2.12
pin "@floating-ui/utils/dom", to: "@floating-ui--utils--dom.js", preload: false # @0.2.12
# Chart.js UMD (analytics page). The ESM graph needs an unpinned helpers chunk.
# Downloaded from unpkg: chart.js@4.5.1/dist/chart.umd.min.js
pin "chart.js", preload: false # @4.5.1
