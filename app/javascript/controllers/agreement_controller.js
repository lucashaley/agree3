import { Controller } from "@hotwired/stimulus"

// Manages anonymous user agreements using localStorage
export default class extends Controller {
  static values = {
    statementId: Number,
    initialState: Boolean
  }

  connect() {
    // Check if user has agreed to this statement
    this.updateUI()

    // If user is logged in, sync localStorage to server on page load
    if (this.isLoggedIn()) {
      this.syncToServer()
    }
  }

  // Toggle agreement for anonymous users
  toggle(event) {
    event.preventDefault()

    const statementId = this.statementIdValue
    const agreements = this.getAgreements()
    const index = agreements.indexOf(statementId)

    if (index > -1) {
      // Remove agreement
      agreements.splice(index, 1)
    } else {
      // Add agreement
      agreements.push(statementId)
    }

    this.saveAgreements(agreements)
    this.updateUI()

    // If logged in, also update server
    if (this.isLoggedIn()) {
      this.syncToServer()
    }
  }

  // Get agreements from localStorage
  getAgreements() {
    const stored = localStorage.getItem('statement_agreements')
    return stored ? JSON.parse(stored) : []
  }

  // Save agreements to localStorage
  saveAgreements(agreements) {
    localStorage.setItem('statement_agreements', JSON.stringify(agreements))

    // Dispatch event for other controllers to listen to
    window.dispatchEvent(new CustomEvent('agreements-updated', {
      detail: { agreements }
    }))
  }

  // Check if statement is agreed
  hasAgreed() {
    // If logged in, use server state
    if (this.isLoggedIn()) {
      return this.initialStateValue
    }

    // Otherwise check localStorage
    const agreements = this.getAgreements()
    return agreements.includes(this.statementIdValue)
  }

  // Update UI based on agreement state
  updateUI() {
    const agreed = this.hasAgreed()
    const button = this.element.querySelector('[data-agreement-target="button"]')
    const badge = this.element.querySelector('[data-agreement-target="badge"]')

    if (button) {
      if (agreed) {
        button.classList.add('btn-active')
        button.textContent = button.dataset.agreedText || 'Agreed ✓'
      } else {
        button.classList.remove('btn-active')
        button.textContent = button.dataset.defaultText || 'Agree'
      }
    }

    if (badge) {
      badge.style.display = agreed ? 'inline-block' : 'none'
    }
  }

  // Check if user is logged in (has session)
  isLoggedIn() {
    // Check if there's a user indicator in the DOM
    return document.querySelector('[data-user-logged-in]') !== null
  }

  // Sync localStorage agreements to server
  async syncToServer() {
    const agreements = this.getAgreements()

    if (agreements.length === 0) return

    try {
      const response = await fetch('/statements/sync_agreements', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken()
        },
        body: JSON.stringify({ statement_ids: agreements })
      })

      if (response.ok) {
        console.log('Agreements synced to server')
        // Optionally clear localStorage after successful sync
        // localStorage.removeItem('statement_agreements')
      }
    } catch (error) {
      console.error('Failed to sync agreements:', error)
    }
  }

  // Get CSRF token for fetch requests
  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ''
  }
}
