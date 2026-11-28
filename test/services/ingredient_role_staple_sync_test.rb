require "test_helper"

class IngredientRoleStapleSyncTest < ActiveSupport::TestCase
  def row(name, family, role, staple)
    { "ingredient_name" => name, "family_name" => family, "role" => role, "is_pantry_staple" => staple.to_s }
  end

  test "sets role and staple flag only" do
    onion = Ingredient.create!(name: "zz test onion", is_pantry_staple: true, relationship_type: "canonical")
    IngredientRoleStapleSync.new([row("zz test onion", "onions", "aromatic", false)]).call
    onion.reload
    assert_equal "aromatic", onion.role
    refute onion.is_pantry_staple
    assert_equal "canonical", onion.relationship_type
  end

  test "raises when an ingredient is missing from the DB" do
    assert_raises(StandardError) { IngredientRoleStapleSync.new([row("ghost", "g", "protein", false)]).call }
  end

  test "raises on invalid roles and changes nothing" do
    egg = Ingredient.create!(name: "zz test egg")
    assert_raises(StandardError) { IngredientRoleStapleSync.new([row("zz test egg", "whole eggs", "meat", false)]).call }
    assert_nil egg.reload.role
  end
end
