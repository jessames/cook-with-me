class AddClassificationToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :ingredients, :equivalence_key, :bigint
    add_column :ingredients, :relationship_type, :string
    add_column :ingredients, :review_needed, :boolean, default: false
  end
end
