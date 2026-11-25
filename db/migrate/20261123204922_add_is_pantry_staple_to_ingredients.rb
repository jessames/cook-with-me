class AddIsPantryStapleToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :ingredients, :is_pantry_staple, :boolean, default: false, null: false
  end
end
