import "trix"
import "@rails/actiontext"

const allowedTypes = ["image/png", "image/jpg", "image/jpeg", "image/gif"]

document.addEventListener("trix-file-accept", e => {
  if (!allowedTypes.includes(e.file.type)) {
    e.preventDefault()
    alert("Only images are allowed!")
  }
})

Trix.config.attachments.preview.caption = { name: false, size: false }
