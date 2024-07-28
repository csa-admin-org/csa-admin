import "@hotwired/turbo-rails"
import "controllers/members"

import "flowbite"
// https://github.com/themesberg/flowbite/issues/88#issuecomment-1962238351
window.document.addEventListener("turbo:submit-end", (_event) => {
  window.setTimeout(() => {
    window.initFlowbite()
  }, 10)
})
