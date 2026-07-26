import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["friendGroup", "guestGroup"]

  toggle(event) {
    const type = event.target.value
    if (type === "friend") {
      this.friendGroupTarget.disabled = false
      this.guestGroupTarget.disabled = true
    } else {
      this.friendGroupTarget.disabled = true
      this.guestGroupTarget.disabled = false
    }
  }
}
