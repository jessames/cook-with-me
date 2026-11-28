class ApplyIngredientRolesAndStaples < ActiveRecord::Migration[8.1]
  def up
    if Ingredient.none?
      say "Empty database — ingredient roles will be imported during seeding."
      return
    end

    IngredientRoleStapleSync.new.call
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
