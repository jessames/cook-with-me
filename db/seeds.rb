# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
require "net/http"
require "json"

ActiveRecord::Base.transaction do
  ("a".."z").each do |letter|
    url = URI("https://www.themealdb.com/api/json/v1/1/search.php?f=#{letter}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    meals = data["meals"] || []

    meals.each do |meal|
      recipe = Recipe.find_or_create_by!(external_id: meal["idMeal"]) do |record|
        record.name = meal["strMeal"]
        record.image_url = meal["strMealThumb"]
        record.source_category = meal["strCategory"]
      end

      (1..20).each do |number|
        ingredient_name = meal["strIngredient#{number}"]&.strip
        measurement_text = meal["strMeasure#{number}"]&.strip

        next if ingredient_name.nil? || ingredient_name.empty?

        ingredient = Ingredient.find_or_create_by!(
          name: ingredient_name.downcase
        )

        if ingredient.image_url.blank?
          image_name = ERB::Util.url_encode(ingredient_name.titleize)
          ingredient.update!(
            image_url: "https://www.themealdb.com/images/ingredients/#{image_name}.png"
          )
        end

        Measurement.find_or_create_by!(
          recipe: recipe,
          ingredient: ingredient
        ) do |measurement|
          measurement.measure_value = measurement_text
        end
      end

      steps = meal["strInstructions"]
        .to_s
        .split(/\r?\n/)
        .map(&:strip)
        .reject(&:empty?)

      steps.each_with_index do |step, index|
        Instruction.find_or_create_by!(
          recipe: recipe,
          instruction_number: index + 1
        ) do |instruction|
          instruction.instruction_content = step
        end
      end
    end

    puts "Imported recipes beginning with #{letter.upcase}: #{meals.length}"
  end

  puts "Applying recipe repairs and classifications..."

  RecipeDataImportService.new.call

  puts "Total recipes in database: #{Recipe.count}"
end
