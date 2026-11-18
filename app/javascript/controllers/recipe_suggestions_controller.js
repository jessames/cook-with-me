import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { recipes: Array }

  connect() {
    localStorage.setItem(
      "recipeSuggestions",
      JSON.stringify(this.recipesValue)
    )
  }
}
