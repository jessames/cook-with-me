require_relative "../../lib/reviewed_instruction_cleanup"

class ApplyReviewedInstructionEdits < ActiveRecord::Migration[8.1]
  class RecipeRow < ActiveRecord::Base
    self.table_name = "recipes"
  end

  class InstructionRow < ActiveRecord::Base
    self.table_name = "instructions"
  end

  class MessageRow < ActiveRecord::Base
    self.table_name = "messages"
  end

  def up
    execute "LOCK TABLE instructions, messages IN SHARE ROW EXCLUSIVE MODE"
    applied = 0
    joined = 0

    RecipeRow.where(external_id: ReviewedInstructionCleanup::PLANS.keys).each do |recipe|
      rows = InstructionRow.where(recipe_id: recipe.id).order(:instruction_number, :id).to_a
      plan = ReviewedInstructionCleanup.plan(recipe.external_id, rows.map(&:instruction_content))
      unless plan && rows.map(&:instruction_number) == (1..rows.size).to_a
        say "Skipped #{recipe.name}: instruction text or numbering differs from the reviewed export"
        next
      end

      offset = 0
      groups = plan.map do |length, prefix_length|
        steps = rows.slice(offset, length)
        offset += length
        [steps, prefix_length]
      end
      continuation_ids = groups.flat_map { |steps, _| steps.drop(1).map(&:id) }
      if MessageRow.where(instruction_id: continuation_ids).exists?
        say "Skipped #{recipe.name}: a continuation row has chat messages"
        next
      end

      joined += InstructionRow.where(id: continuation_ids).delete_all
      groups.each_with_index do |(steps, prefix_length), index|
        step = steps.first
        changes = {}
        text = ReviewedInstructionCleanup.join_texts(steps.map(&:instruction_content), prefix_length)
        changes[:instruction_content] = text if step.instruction_content != text
        changes[:instruction_number] = index + 1 if step.instruction_number != index + 1
        step.update_columns(changes) if changes.any?
      end
      applied += 1
    end

    say "Applied reviewed edits to #{applied} recipes and joined #{joined} continuation rows"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Original instruction boundaries and prefixes were removed"
  end
end
