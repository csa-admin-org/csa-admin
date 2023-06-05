import { Application } from "@hotwired/stimulus"
import Sortable from 'stimulus-sortable'

const application = Application.start()
application.register('sortable', Sortable)

// Configure Stimulus development experience
application.warnings = true
application.debug = false
window.Stimulus = application

export { application }
