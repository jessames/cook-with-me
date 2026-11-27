require_relative "../../lib/instruction_cleanup_v1"

class StripZeroPaddedInstructionPrefixes < ActiveRecord::Migration[8.1]
  class InstructionRow < ActiveRecord::Base
    self.table_name = "instructions"
  end

  def up
    execute "LOCK TABLE instructions IN SHARE ROW EXCLUSIVE MODE"
    updated = 0

    InstructionRow.order(:recipe_id, :instruction_number, :id).to_a.group_by(&:recipe_id).each_value do |rows|
      next unless rows.map(&:instruction_number) == (1..rows.size).to_a

      texts = rows.map(&:instruction_content)
      cleaned = InstructionCleanupV1.without_zero_padded_prefixes(texts)
      rows.zip(cleaned).each do |row, text|
        next if row.instruction_content == text

        row.update_columns(instruction_content: text)
        updated += 1
      end
    end

    say "Stripped #{updated} zero-padded instruction prefixes"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Original instruction prefixes were removed"
  end
end
