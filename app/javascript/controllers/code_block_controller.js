import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["code", "copyButton"]

  connect() {
    if (window.hljs && this.hasCodeTarget) {
      window.hljs.highlightElement(this.codeTarget)
    }
  }

  copy() {
    const text = this.codeTarget.textContent
    navigator.clipboard.writeText(text).then(() => {
      this.copyButtonTarget.textContent = "Copied!"
      setTimeout(() => { this.copyButtonTarget.textContent = "Copy" }, 2000)
    })
  }
}
