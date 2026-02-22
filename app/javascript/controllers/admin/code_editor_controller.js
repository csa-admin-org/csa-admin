import { Controller } from "@hotwired/stimulus"
import { hide } from "components/utils"
import { debounce } from "throttle-debounce"
import { CodeJar } from "codejar"
import Prism from "prismjs"

window.Prism = Prism

import "prismjs/components/prism-yaml"
import "prismjs/components/prism-markup-templating"
import "prismjs/components/prism-liquid"

export default class extends Controller {
  static get targets() {
    return ["editor", "form"]
  }
  static get values() {
    return { previewPath: String }
  }

  initialize() {
    this.updatePreview = debounce(500, this.updatePreview)
  }

  editorTargetConnected(element) {
    hide(element)

    const editDiv = document.createElement("div")
    editDiv.className = "codejar-editor"

    const mode = element.dataset.mode || "markup"
    const languageClass = `language-${mode}`
    editDiv.classList.add(languageClass)

    element.parentNode.insertBefore(editDiv, element)

    const highlight = (editor) => {
      const code = editor.textContent
      const grammar = Prism.languages[mode] || Prism.languages.markup
      editor.innerHTML = Prism.highlight(code, grammar, mode)
    }

    this.jar = CodeJar(editDiv, highlight, {
      tab: "  ",
      indentOn: /[{(\[]$/,
      addClosing: true,
      history: true,
      catchTab: true,
      preserveIdent: true
    })

    this.jar.updateCode(element.value)

    this.jar.onUpdate((code) => {
      element.value = code
      this.updatePreview()
    })
  }

  disconnect() {
    this.jar?.destroy()
  }

  updatePreview() {
    const path = this.previewPathValue

    if (this.hasFormTarget && path) {
      const formData = new FormData(this.formTarget)
      formData.delete("_method") // remove PATCH Rails form _method
      const params = new URLSearchParams(formData)
      fetch(path, {
        method: "POST",
        body: params
      })
        .then((response) => response.text())
        .then((js) => {
          try {
            eval(js)
          } catch (e) {
            console.error(e)
          }
        })
    }
  }
}
