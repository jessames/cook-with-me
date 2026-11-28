class AddRoleToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :ingredients, :role, :string
  end
end
