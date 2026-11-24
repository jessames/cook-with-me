class CreateIngredientFamilies < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredient_families do |t|
      t.string :name

      t.timestamps
    end
  end
end
