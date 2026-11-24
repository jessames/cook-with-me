class AddClassificationToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :dish_role, :string, default: nil, null: true
    add_column :recipes, :meal_types, :string, array: true, default: [], null: false
    add_column :recipes, :recommendation_eligible, :boolean, default: false, null: false
    add_column :recipes, :review_needed, :boolean, default: true, null: false
  end
end
