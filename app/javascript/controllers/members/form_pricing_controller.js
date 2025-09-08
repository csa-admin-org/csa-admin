import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get values() {
    return { url: String }
  }

  connect() {
    this.refresh()
  }

  refresh() {
    if (!document.querySelector('turbo-frame[id="pricing"]')) {
      return
    }

    const form = this.element
    const data = new FormData(form)
    data.delete("authenticity_token")
    data.delete("member[name]")
    data.delete("member[address]")
    data.delete("member[zip]")
    data.delete("member[city]")
    data.delete("member[country_code]")
    data.delete("member[emails]")
    data.delete("member[phones]")
    data.delete("member[profession]")
    data.delete("member[come_from]")
    data.delete("member[note]")
    data.delete("member[terms_of_service]")
    const url = new URL(this.urlValue)
    url.search = new URLSearchParams(data).toString()

    Turbo.visit(url, { frame: "pricing" })
  }
}
