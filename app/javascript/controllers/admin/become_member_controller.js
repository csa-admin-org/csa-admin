import { Controller } from "@hotwired/stimulus"

// Cmd-click posts the form in a new browsing context. Chrome then sends
// Sec-Fetch-Site: none, which Rails 8.2 rejects on HTTPS. Open the tab during
// the click, then point it at the URL from a same-origin fetch.
export default class extends Controller {
  async open(event) {
    event.preventDefault()

    const tab = window.open("", "_blank")
    const response = await fetch(this.element.form.action, {
      method: "POST",
      headers: { Accept: "application/json" },
      body: new FormData(this.element.form),
      credentials: "same-origin",
      redirect: "manual"
    })

    if (!response.ok) {
      tab?.close()
      return
    }

    const { url } = await response.json()
    if (tab && url) {
      tab.opener = null
      tab.location = url
    }
  }
}
