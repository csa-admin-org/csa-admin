import { Controller } from "@hotwired/stimulus"
import { hide } from "components/utils"

export default class extends Controller {
  static targets = ["invoice", "invoiceInput", "member"]
  static values = { invoiceMemberId: String }

  connect() {
    this.clearInvoice()
  }

  clearInvoice() {
    if (this.memberTarget.value == this.invoiceMemberIdValue) return

    this.invoiceInputTarget.value = ""
    hide(this.invoiceTarget)
  }
}
