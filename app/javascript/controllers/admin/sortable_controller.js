import Sortable from '@stimulus-components/sortable'

export default class extends Sortable {
  get defaultOptions() {
    return {
      animation: 150,  // ms, animation speed moving items when sorting, `0` — without animation
      delay: 150, // time in milliseconds to define when the sorting should start
      delayOnTouchOnly: true, // only delay if user is using touch (mobile)
    }
  }
}
