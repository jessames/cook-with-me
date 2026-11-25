class AddInstructionRowToMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :messages, :instruction, null: false, foreign_key: true
  end
end
