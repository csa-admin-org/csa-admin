import { Controller } from "@hotwired/stimulus"
import { hide } from "components/utils"
import { debounce } from "throttle-debounce"
import { EditorView, basicSetup } from "codemirror"
import { EditorState } from "@codemirror/state"
import { yaml } from "@codemirror/lang-yaml"
import { liquid } from "@codemirror/lang-liquid"
import { githubDark } from "@fsegurai/codemirror-theme-github-dark"
import { githubLight } from "@fsegurai/codemirror-theme-github-light"

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
    element.parentNode.insertBefore(editDiv, element)
    const prefersDarkScheme = window.matchMedia(
      "(prefers-color-scheme: dark)"
    ).matches
    const hasDarkClass = document.documentElement.classList.contains("dark")
    const useDarkTheme = prefersDarkScheme || hasDarkClass
    const theme = useDarkTheme ? githubDark : githubLight
    // Initialize CodeMirror editor
    const extensions = [basicSetup, EditorView.lineWrapping, ...theme]
    if (element.dataset.mode === "yaml") {
      extensions.push(yaml())
    } else if (element.dataset.mode === "liquid") {
      extensions.push(liquid())
    }
    extensions.push(
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          element.value = update.state.doc.toString()
          this.updatePreview()
        }
      })
    )
    this.editor = new EditorView({
      state: EditorState.create({
        doc: element.value,
        extensions: extensions
      }),
      parent: editDiv
    })
  }

  disconnect() {
    this.editor?.destroy()
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
