class CreateMeasurements < ActiveRecord::Migration[8.1]
  def change
    create_table :measurements do |t|
      t.references :recipe, null: false, foreign_key: true
      t.string :measure_unit
      t.integer :measure_value

      t.timestamps
    end
  end
end
