import { Controller } from "@hotwired/stimulus"
import { hide } from "components/utils"
import { debounce } from 'throttle-debounce'
import * as ace from "ace-builds"
import "ace-builds/src-noconflict/mode-liquid"
import "ace-builds/src-noconflict/mode-yaml"
import "ace-builds/src-noconflict/theme-dreamweaver"

export default class extends Controller {
  static get targets() {
    return ["editor", "form"]
  }

  initialize() {
    this.updatePreview = debounce(500, this.updatePreview)
  }

  editorTargetConnected(element) {
    hide(element)
    const editDiv = document.createElement("div")
    element.parentNode.insertBefore(editDiv, element)
    var editor = ace.edit(editDiv, {
      mode: 'ace/mode/' + element.dataset.mode,
      theme: 'ace/theme/dreamweaver',
      placeholder: element.placeholder,
      highlightActiveLine: false,
      showGutter: false,
      printMargin: false,
      useSoftTabs: true,
      tabSize: 2,
      wrapBehavioursEnabled: true,
      wrap: true,
      minLines: 10,
      maxLines: 30,
      fontSize: 14
    })
    editor.renderer.setPadding(12)
    editor.getSession().setUseWorker(false);
    editor.getSession().setValue(element.value)
    editor.getSession().on('change', () => {
      element.innerHTML = editor.getSession().getValue()
      this.updatePreview()
    })
  }

  updatePreview() {
    if (this.hasFormTarget) {
      const url = this.formTarget.getAttribute('action') + '/preview.js'
      const params = (new URLSearchParams(new FormData(this.formTarget))).toString()
      fetch(url + '?' + params, {
        method: 'GET'
      }).then(response => response.text()).then(js => eval(js))
    }
  }
}
