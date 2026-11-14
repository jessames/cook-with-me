class AddIngredientToMeasurements < ActiveRecord::Migration[8.1]
  def change
    add_reference :measurements, :ingredient, null: false, foreign_key: true
  end
end
