import "trix"
import "@rails/actiontext"

const allowedTypes = ["image/png", "image/jpg", "image/jpeg", "image/gif"]
const maxImageSize = 512000

document.addEventListener("trix-file-accept", e => {
  if (e.file.size > maxImageSize) {
    e.preventDefault()
    alert("Only images smaller than 512KB are allowed!")
  }
  if (!allowedTypes.includes(e.file.type)) {
    e.preventDefault()
    alert("Only images are allowed!")
  }
})

Trix.config.attachments.preview.caption = { name: false, size: false }
