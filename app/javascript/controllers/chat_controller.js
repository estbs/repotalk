import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  connect() {
    this.source = null
  }

  disconnect() {
    this.source?.close()
  }

  submit(event) {
    event.preventDefault()

    const question = this.inputTarget.value.trim()
    if (!question || this.source) return

    this.inputTarget.value = ""
    this.submitTarget.disabled = true

    const url = new URL(this.element.action, window.location.origin)
    url.searchParams.set("question", question)

    this.source = new EventSource(url.toString())

    this.source.onmessage = (e) => {
      Turbo.renderStreamMessage(e.data)
      this.#scrollToBottom()
    }

    this.source.addEventListener("done", () => {
      this.source.close()
      this.source = null
      this.submitTarget.disabled = false
      this.inputTarget.focus()
    })

    this.source.onerror = () => {
      this.source.close()
      this.source = null
      this.submitTarget.disabled = false
    }
  }

  #scrollToBottom() {
    const messages = document.getElementById("chat-messages")
    if (messages) messages.scrollTop = messages.scrollHeight
  }
}
