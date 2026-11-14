class CreateInstructions < ActiveRecord::Migration[8.1]
  def change
    create_table :instructions do |t|
      t.integer :instruction_number
      t.text :instruction_content
      t.references :recipe, null: false, foreign_key: true

      t.timestamps
    end
  end
end
