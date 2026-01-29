import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide"]

  connect() {
    this.currentIndex = 0
    this.showSlide(this.currentIndex)
    this.startCarousel()
  }

  disconnect() {
    this.stopCarousel()
  }

  startCarousel() {
    // Only start auto-rotation if there's more than one slide
    if (this.slideTargets.length > 1) {
      this.intervalId = setInterval(() => {
        this.nextSlide()
      }, 6000) // 6 seconds
    }
  }

  stopCarousel() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
    }
  }

  nextSlide() {
    // Only rotate if there's more than one slide
    if (this.slideTargets.length <= 1) return

    // Hide current slide
    this.slideTargets[this.currentIndex].classList.remove("active")
    this.slideTargets[this.currentIndex].style.display = "none"

    // Move to next slide (random)
    const availableIndices = [...Array(this.slideTargets.length).keys()]
      .filter(i => i !== this.currentIndex)
    this.currentIndex = availableIndices[Math.floor(Math.random() * availableIndices.length)]

    // Show new slide
    this.showSlide(this.currentIndex)
  }

  showSlide(index) {
    this.slideTargets[index].style.display = "block"
    // Force reflow to ensure transition works
    this.slideTargets[index].offsetHeight
    this.slideTargets[index].classList.add("active")
  }
}
