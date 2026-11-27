require_relative "../../lib/instruction_cleanup_v1"

class CleanRecipeInstructions < ActiveRecord::Migration[8.1]
  class InstructionRow < ActiveRecord::Base
    self.table_name = "instructions"
  end

  class MessageRow < ActiveRecord::Base
    self.table_name = "messages"
  end

  def up
    # Prevent new references or instruction edits while checking and deleting rows.
    execute "LOCK TABLE instructions, messages IN SHARE ROW EXCLUSIVE MODE"

    removed = 0
    stripped = 0

    InstructionRow.order(:recipe_id, :instruction_number, :id).to_a.group_by(&:recipe_id).each do |recipe_id, rows|
      markers, surviving = rows.partition do |row|
        InstructionCleanupV1.standalone_marker?(row.instruction_content)
      end

      if markers.any?
        marker_ids = markers.map(&:id)
        if surviving.empty? || MessageRow.where(instruction_id: marker_ids).exists?
          say "Skipped recipe #{recipe_id}: marker rows have chat references or no steps would remain", true
          next
        end

        removed += InstructionRow.where(id: marker_ids).delete_all
        surviving.each_with_index do |row, index|
          number = index + 1
          row.update_columns(instruction_number: number) if row.instruction_number != number
        end
      else
        original = rows.map(&:instruction_content)
        cleaned = InstructionCleanupV1.without_numbered_prefixes(original)
        rows.zip(cleaned).each do |row, text|
          next if row.instruction_content == text

          row.update_columns(instruction_content: text)
          stripped += 1
        end
      end
    end

    say "Removed #{removed} standalone rows and stripped #{stripped} numbered prefixes"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Original instruction rows and prefixes were removed"
  end
end
