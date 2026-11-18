
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "suggestions", "selected", "emptyMessage"]
  static values = { ingredients: Array }

  connect() {
    this.selectedIngredients = []
  }

  search() {
    const query = this.inputTarget.value.trim().toLowerCase()
    this.suggestionsTarget.innerHTML = ""

    if (!query) return

    const matches = this.ingredientsValue.filter(ingredient =>
      ingredient.name.toLowerCase().includes(query) &&
      !this.selectedIngredients.some(selected => selected.id === ingredient.id)
    )

    matches.slice(0, 10).forEach(ingredient => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "ingredient-suggestion"
      button.textContent = ingredient.name
      button.dataset.id = ingredient.id
      button.dataset.action = "click->ingredient-search#addIngredient"

      this.suggestionsTarget.appendChild(button)
    })
  }

  addIngredient(event) {
    const id = Number(event.currentTarget.dataset.id)
    const ingredient = this.ingredientsValue.find(item => item.id === id)

    if (!ingredient) return
    if (this.selectedIngredients.some(item => item.id === id)) return

    this.selectedIngredients.push(ingredient)

    this.inputTarget.value = ""
    this.suggestionsTarget.innerHTML = ""

    this.renderSelected()
  }

  removeIngredient(event) {
    const id = Number(event.currentTarget.dataset.id)

    this.selectedIngredients = this.selectedIngredients.filter(
      ingredient => ingredient.id !== id
    )

    this.renderSelected()
  }

  renderSelected() {
    this.selectedTarget.innerHTML = ""

    this.selectedIngredients.forEach(ingredient => {
      const card = document.createElement("div")
      card.className = "selected-ingredient-card"

      // Ingredient thumbnail from our database
      const imageContainer = document.createElement("div")
      imageContainer.className = "ingredient-image-container"

      if (ingredient.image_url) {
        const image = document.createElement("img")
        image.src = ingredient.image_url
        image.alt = ingredient.name
        image.className = "selected-ingredient-image"
        image.loading = "lazy"

        image.onerror = () => {
          image.remove()
          imageContainer.textContent = "🍳"
          imageContainer.classList.add("ingredient-image-placeholder")
        }

        imageContainer.appendChild(image)
      } else {
        imageContainer.textContent = "🍳"
        imageContainer.classList.add("ingredient-image-placeholder")
      }

      // Ingredient name
      const name = document.createElement("span")
      name.className = "selected-ingredient-name"
      name.textContent = ingredient.name

      // Hidden field containing the ingredient ID
      const hiddenInput = document.createElement("input")
      hiddenInput.type = "hidden"
      hiddenInput.name = "ingredients[]"
      hiddenInput.value = ingredient.id

      // Remove button
      const removeButton = document.createElement("button")
      removeButton.type = "button"
      removeButton.className = "remove-ingredient-button"
      removeButton.textContent = "×"
      removeButton.setAttribute("aria-label", `Remove ${ingredient.name}`)
      removeButton.dataset.id = ingredient.id
      removeButton.dataset.action = "click->ingredient-search#removeIngredient"

      // Assemble the card
      card.appendChild(imageContainer)
      card.appendChild(name)
      card.appendChild(hiddenInput)
      card.appendChild(removeButton)

      this.selectedTarget.appendChild(card)
    })

    this.emptyMessageTarget.hidden = this.selectedIngredients.length > 0
  }
}
