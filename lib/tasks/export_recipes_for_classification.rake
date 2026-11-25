require "csv"

namespace :recipes do
  desc "Export recipes for meal type and dish role classification"

  task export_classification: :environment do
    path = Rails.root.join("db", "recipe_classification_export.csv")

    recipes = Recipe.includes(
      measurements: :ingredient,
      instructions: []
    ).order(:id)

    CSV.open(path, "w", write_headers: true, headers: [
      "recipe_id",
      "recipe_name",
      "source_category",
      "ingredients",
      "instructions"
    ]) do |csv|
      recipes.each do |recipe|
        ingredient_names = recipe.measurements
          .map { |measurement| measurement.ingredient.name }
          .uniq
          .join("; ")

        instruction_text = recipe.instructions
          .sort_by(&:instruction_number)
          .map(&:instruction_content)
          .join("\n")

        csv << [
          recipe.id,
          recipe.name,
          recipe.source_category,
          ingredient_names,
          instruction_text
        ]
      end
    end

    puts "Recipe export completed!"
    puts "Recipes exported: #{recipes.size}"
    puts "File: #{path}"
  end
end
