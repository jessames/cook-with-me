require "test_helper"
require "csv"

class IngredientClassificationCheckTest < ActiveSupport::TestCase
  CSV_PATH = Rails.root.join("db/data/ingredient_classification.csv")

  def row(name, family, role)
    { "ingredient_name" => name, "family_name" => family, "role" => role }
  end

  def csv_rows
    CSV.read(CSV_PATH, headers: true)
  end

  test "valid rows have no errors" do
    assert_empty IngredientClassificationCheck.errors([row("chicken", "chicken meat", "protein")])
  end

  test "blank and unknown roles are errors" do
    errors = IngredientClassificationCheck.errors([row("a", "f1", ""), row("b", "f2", "meat")])
    assert_equal 2, errors.size
    assert(errors.any? { _1.include?("a") })
    assert(errors.any? { _1.include?("b") })
  end

  test "inconsistent roles within a family are an error" do
    errors = IngredientClassificationCheck.errors(
      [row("eggs", "whole eggs", "protein"), row("egg", "whole eggs", "dairy")]
    )
    assert(errors.any? { _1.include?("whole eggs") })
  end

  test "real CSV passes the check" do
    assert_empty IngredientClassificationCheck.errors(csv_rows)
  end

  test "real CSV staples are exactly the agreed list" do
    staples = csv_rows.select { _1["is_pantry_staple"] == "true" }.map { _1["ingredient_name"] }
    assert_equal IngredientClassificationCheck::PANTRY_STAPLES.sort, staples.sort
  end

  test "eggs are protein and not staples" do
    eggs = csv_rows.select { _1["family_name"] == "whole eggs" }
    assert eggs.any?
    assert(eggs.all? { _1["role"] == "protein" && _1["is_pantry_staple"] == "false" })
  end
end
