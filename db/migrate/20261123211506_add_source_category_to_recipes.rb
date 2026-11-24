class AddSourceCategoryToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :source_category, :string
  end
end
