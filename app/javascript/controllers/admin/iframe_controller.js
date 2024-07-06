import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static get targets() {
    return ["iframe"]
  }

  connect() {
    let toggleColorThemeButton = document.querySelector("button.dark-mode-toggle")
    toggleColorThemeButton.addEventListener("mouseup", () => {
      this._toggleColorScheme()
    })
  }

  iframeTargetConnected(element) {
    element.onload = () => {
      this._resize()
      this._setColorScheme()
    }
    this._resize()
    this._setColorScheme()
  }

  _resize() {
    const heights = this._iframeBodies().map(body => body.offsetHeight)
    this.iframeTargets.forEach(i => i.style.height = Math.max(...heights) + 'px')
  }

  _setColorScheme() {
    if (localStorage.getItem('theme')) {
      if (localStorage.getItem('theme') === 'light') {
        this._iframeBodies().forEach(body => body.classList.remove('dark'))
      } else {
        this._iframeBodies().forEach(body => body.classList.add('dark'))
      }
    }
  }

  _toggleColorScheme() {
    this._iframeBodies().forEach(body => {
      if (body.classList.contains('dark')) {
        body.classList.remove('dark')
      } else {
        body.classList.add('dark')
      }
    })
  }

  _iframeBodies() {
    return this.iframeTargets.map(i => i.contentWindow.document.body).filter(Boolean)
  }
}
