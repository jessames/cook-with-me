import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "suggestions", "selected"]
  static values = { ingredients: Array }

  connect() {
    this.selectedIngredients = []
  }

  search() {
    const query = this.inputTarget.value.trim().toLowerCase()
    this.suggestionsTarget.innerHTML = ""

    if (query.length === 0) return

    const matches = this.ingredientsValue
      .filter(ingredient =>
        ingredient.name.toLowerCase().includes(query)
      )
      .filter(ingredient =>
        !this.selectedIngredients.some(
          selected => selected.id === ingredient.id
        )
      )
      .slice(0, 8)

    if (matches.length === 0) {
      const emptyMessage = document.createElement("p")
      emptyMessage.textContent = "No matching ingredients found."
      this.suggestionsTarget.appendChild(emptyMessage)
      return
    }

    matches.forEach(ingredient => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "ingredient-suggestion"
      button.textContent = ingredient.name

      button.addEventListener("click", () => {
        this.addIngredient(ingredient)
      })

      this.suggestionsTarget.appendChild(button)
    })
  }

  addIngredient(ingredient) {
    this.selectedIngredients.push(ingredient)
    this.inputTarget.value = ""
    this.suggestionsTarget.innerHTML = ""
    this.renderSelected()
  }

  removeIngredient(id) {
    this.selectedIngredients = this.selectedIngredients.filter(
      ingredient => ingredient.id !== id
    )

    this.renderSelected()
  }

  renderSelected() {
    this.selectedTarget.innerHTML = ""

    if (this.selectedIngredients.length === 0) {
      const message = document.createElement("p")
      message.textContent = "You haven't added any ingredients yet."
      this.selectedTarget.appendChild(message)
      return
    }

    this.selectedIngredients.forEach((ingredient, index) => {
      const row = document.createElement("div")
      row.className = "selected-ingredient"

      const name = document.createElement("span")
      name.textContent = ingredient.name

      const quantity = document.createElement("input")
      quantity.type = "number"
      quantity.min = "0"
      quantity.step = "any"
      quantity.placeholder = "Quantity"
      quantity.name = "quantities[]"

      const unit = document.createElement("input")
      unit.type = "text"
      unit.placeholder = "Unit (e.g. grams)"
      unit.name = "units[]"

      const id = document.createElement("input")
      id.type = "hidden"
      id.name = "ingredient_ids[]"
      id.value = ingredient.id

      const remove = document.createElement("button")
      remove.type = "button"
      remove.textContent = "Remove"
      remove.addEventListener("click", () => {
        this.removeIngredient(ingredient.id)
      })

      row.append(name, id, quantity, unit, remove)
      this.selectedTarget.appendChild(row)
    })
  }
}
