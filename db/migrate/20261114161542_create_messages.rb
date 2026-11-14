class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.string :role
      t.references :session, null: false, foreign_key: true
      t.text :content

      t.timestamps
    end
  end
end
