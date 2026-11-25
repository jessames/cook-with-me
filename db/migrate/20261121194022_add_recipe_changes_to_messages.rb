class AddRecipeChangesToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :proposed_change, :jsonb
    add_column :messages, :accepted_at, :datetime
  end
end
