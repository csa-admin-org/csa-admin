import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["iframe"]
  }

  connect() {
    let toggleColorThemeButton = document.querySelector("button.dark-mode-toggle")
    toggleColorThemeButton.addEventListener("mouseup", () => {
      this.toggleColorScheme()
    })
  }

  iframeTargetConnected(element) {
    element.onload = () => {
      this.resize()
      this.setColorScheme()
    }
    this.resize()
    this.setColorScheme()
  }

  resize() {
    const heights = this.iframeTargets.map(i => i.contentWindow.document.body ? i.contentWindow.document.body.offsetHeight : 0);
    this.iframeTargets.forEach(i => i.style.height = Math.max(...heights) + 'px');
  }

  setColorScheme() {
    if (localStorage.getItem('theme')) {
      if (localStorage.getItem('theme') === 'light') {
        this.iframeTargets.forEach(i => i.contentWindow.document.body.classList.remove('dark'))
      } else {
        this.iframeTargets.forEach(i => i.contentWindow.document.body.classList.add('dark'))
      }
    }
  }

  toggleColorScheme() {
    this.iframeTargets.forEach(i => {
      if (i.contentWindow.document.body.classList.contains('dark')) {
        i.contentWindow.document.body.classList.remove('dark')
      } else {
        i.contentWindow.document.body.classList.add('dark')
      }
    })
  }
}
