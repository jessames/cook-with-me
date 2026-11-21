class AddUniqueIndexToFavorites < ActiveRecord::Migration[8.1]
  def change
    add_index :favorites, [:user_id, :recipe_id], unique: true
  end
end
