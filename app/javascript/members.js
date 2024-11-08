import "components/appsignal"
import "@hotwired/turbo-rails"
import "controllers/members"
import "components/browser_update"

import "flowbite"
// https://github.com/themesberg/flowbite/issues/88#issuecomment-1962238351
window.document.addEventListener("turbo:submit-end", (_event) => {
  window.setTimeout(() => {
    window.initFlowbite()
  }, 10)
})
