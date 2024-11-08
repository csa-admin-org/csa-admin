import "components/appsignal"
import "@hotwired/turbo-rails"
import "admin/trix"
import "controllers/admin"
import "components/browser_update"

// Active Admin
import "flowbite"
// https://github.com/themesberg/flowbite/issues/88#issuecomment-1962238351
window.document.addEventListener("turbo:submit-end", (_event) => {
  window.setTimeout(() => {
    window.initFlowbite()
  }, 10)
});

import Rails from "@rails/ujs"
import "active_admin/features/batch_actions"
import "active_admin/features/dark_mode_toggle"
import "active_admin/features/has_many"
import "active_admin/features/filters"
import "active_admin/features/main_menu"
import "active_admin/features/per_page"

Rails.start()
