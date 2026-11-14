class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.string :name
      t.string :image_url
      t.boolean :cooked

      t.timestamps
    end
  end
end
