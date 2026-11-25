class ImportRecipeData < ActiveRecord::Migration[8.1]
  def up
    if Recipe.none? && Ingredient.none?
      say "Empty database — recipe data will be imported during seeding."
      return
    end

    RecipeDataImportService.new.call
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
