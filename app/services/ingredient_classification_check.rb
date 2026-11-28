module IngredientClassificationCheck
  PANTRY_STAPLES = [
    "salt", "sea salt", "kosher salt", "coarse salt",
    "pepper", "black pepper", "ground black pepper", "peppercorns", "whole black peppercorns",
    "water", "cold water", "warm water", "boiling water",
    "oil", "vegetable oil", "sunflower oil", "canola oil", "rapeseed oil", "high heat cooking oil",
    "olive oil", "extra virgin olive oil",
    "sugar", "granulated sugar",
    "flour", "plain flour", "all purpose flour", "white flour",
    "butter", "salted butter", "unsalted butter", "melted butter"
  ].freeze

  def self.errors(rows)
    role_errors(rows) + family_errors(rows)
  end

  def self.role_errors(rows)
    rows.filter_map do |row|
      role = row["role"].to_s
      next if Ingredient::ROLES.include?(role)

      role.empty? ? "Missing role: #{row['ingredient_name']}" : "Unknown role '#{role}': #{row['ingredient_name']}"
    end
  end

  def self.family_errors(rows)
    rows.group_by { |row| row["family_name"] }.filter_map do |family, family_rows|
      roles = family_rows.map { |row| row["role"] }.uniq
      "Inconsistent roles in family #{family}: #{roles.join(', ')}" if roles.size > 1
    end
  end

  private_class_method :role_errors, :family_errors
end
