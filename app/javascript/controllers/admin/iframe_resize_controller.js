import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["iframe"]
  }

  iframeTargetConnected(element) {
    element.onload = () => { this.resize() }
    this.resize()
  }

  resize() {
    const heights = this.iframeTargets.map(i => i.contentWindow.document.body.offsetHeight)
    this.iframeTargets.forEach(i => i.style.height = Math.max(...heights) + 'px');
  }
}
