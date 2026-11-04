import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "spinner"]
  static values = { src: String, worker: String }

  connect() {
    this.renderPage()
  }

  async renderPage() {
    if (!this.hasCanvasTarget || !this.srcValue) return

    try {
      const pdfjs = await import("pdfjs-dist")
      pdfjs.GlobalWorkerOptions.workerSrc = this.workerValue

      const pdf = await pdfjs.getDocument({
        url: this.srcValue,
        isEvalSupported: false
      }).promise
      const page = await pdf.getPage(1)
      const canvas = this.canvasTarget
      const width = canvas.clientWidth || canvas.parentElement.clientWidth
      const scale = (width / page.getViewport({ scale: 1 }).width) * window.devicePixelRatio
      const viewport = page.getViewport({ scale })

      canvas.width = viewport.width
      canvas.height = viewport.height
      await page.render({
        canvasContext: canvas.getContext("2d"),
        viewport
      }).promise
      this.element.classList.add("is-ready")
    } catch (error) {
      if (this.hasSpinnerTarget) this.spinnerTarget.hidden = true
      throw error
    }
  }
}
