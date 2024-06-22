import "@hotwired/turbo-rails"
import "controllers/members"

import "flowbite"
// https://github.com/themesberg/flowbite/issues/88#issuecomment-1962238351
window.document.addEventListener("turbo:submit-end", (_event) => {
  window.setTimeout(() => {
    window.initFlowbite()
  }, 10)
})

// https://flowbite.com/docs/customize/dark-mode/#dark-mode-switcher
if (localStorage.getItem('color-theme') === 'dark' || (!('color-theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
  document.documentElement.classList.add('dark')
} else {
  document.documentElement.classList.remove('dark')
}
