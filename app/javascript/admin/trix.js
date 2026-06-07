import "trix"
import "@rails/actiontext"

const allowedTypes = ["image/png", "image/jpg", "image/jpeg", "image/gif", "image/webp"]
const maxImageSize = 5 * 1024 * 1024 // 5MB (variants will compress images)

document.addEventListener("trix-file-accept", (e) => {
  if (e.file.size > maxImageSize) {
    e.preventDefault()
    alert("Only images smaller than 5MB are allowed!")
  }
  if (!allowedTypes.includes(e.file.type)) {
    e.preventDefault()
    alert("Only images are allowed!")
  }
})

Trix.config.attachments.preview.caption = { name: false, size: false }

// Turbo morphing removes Trix's generated toolbar while preserving the already-connected editor.
document.addEventListener("turbo:before-render", (event) => {
  if (event.detail.renderMethod !== "morph") return
  if (!document.querySelector("trix-editor") && !event.detail.newBody?.querySelector("trix-editor"))
    return

  event.detail.render = (currentElement, newElement) => currentElement.replaceWith(newElement)
})
