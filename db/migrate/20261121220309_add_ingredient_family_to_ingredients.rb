class AddIngredientFamilyToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_reference :ingredients, :ingredient_family, null: true, foreign_key: true
  end
end
