# Weighted Recipe Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rank recipe suggestions by a role-weighted score (proteins count most, missing ingredients penalised by role), prefer filling recipes for meal-sized requests, and trim pantry staples to true basics.

**Architecture:** A new `role` per ingredient lives in `db/data/ingredient_classification.csv`, is validated by a small pure checker, persisted to `ingredients.role` by the seed import and by a targeted data migration for existing DBs. `RecipeMatcher` keeps its exact/related matching but replaces its sort with a weighted score plus a "filling first" partition.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest (parallel), CSV stdlib.

**Spec:** `docs/superpowers/specs/2026-11-28-weighted-recipe-matching-design.md`

## Global Constraints

- Roles (exact strings): `protein`, `starch`, `produce`, `dairy`, `aromatic`, `seasoning`.
- Starting weights: protein 5, starch 3, produce 2, dairy 2, aromatic 1, seasoning 1; ingredient with no role → 1.
- `RELATED_MATCH_FACTOR = 0.75`, `MISSING_PENALTY = 0.5`.
- `score = Σ weight(matched, related × 0.75) − 0.5 × Σ weight(missing non-staples)`; a matched pair uses the **recipe ingredient's** role.
- Meal-sized meal types: `breakfast`, `lunch`, `dinner`, `any` (blank/nil = `any`). Not `snack`, `dessert`.
- Filling = recipe has ≥1 ingredient with role `protein` or `starch` (owned or missing).
- Pantry staples are exactly these 31 CSV `ingredient_name`s, all others `false`:
  `salt, sea salt, kosher salt, coarse salt, pepper, black pepper, ground black pepper, peppercorns, whole black peppercorns, water, cold water, warm water, boiling water, oil, vegetable oil, sunflower oil, canola oil, rapeseed oil, high heat cooking oil, olive oil, extra virgin olive oil, sugar, granulated sugar, flour, plain flour, all purpose flour, white flour, butter, salted butter, unsalted butter, melted butter`
- Eggs (`whole eggs` family) are `protein`, not staples.
- Data migrations: no-op on empty DB, irreversible, and must **not** run the full `RecipeDataImportService` (its `sync_instructions` can destroy instructions referenced by messages).
- Result hashes keep all existing keys; add `score` and `filling`.
- Rubocop: max line length 120 (`app/` is linted; `db/`, `test/` excluded).

## Review Focus

1. Blank/unknown ingredient ids → `[]`, no exception (pinned in Task 3).
2. A recipe listing the same ingredient twice (two measurements) must not double-count score or missing (Task 3).
3. Two selected ingredients from the same family vs one recipe ingredient: counted once; the second stays available for other recipe ingredients (Task 3).
4. `meal_type: nil` behaves exactly like `"any"`, including the filling rule (Task 4).
5. User selects only staples (e.g. `butter`): recipes using them still return, scored by role (Task 3).

---

### Task 1: Role column and trimmed staples in the classification CSV

**Files:**
- Create: `app/services/ingredient_classification_check.rb`
- Modify: `app/models/ingredient.rb`
- Modify: `db/data/ingredient_classification.csv` (add `role` column as last column; update `is_pantry_staple`)
- Test: `test/services/ingredient_classification_check_test.rb`

**Interfaces:**
- Produces: `Ingredient::ROLES` → `%w[protein starch produce dairy aromatic seasoning]` (frozen).
- Produces: `IngredientClassificationCheck.errors(rows) -> Array<String>` where `rows` is an enumerable of hash-like rows with `"ingredient_name"`, `"family_name"`, `"role"`. Errors for: blank role, role not in `Ingredient::ROLES`, a `family_name` whose rows have more than one distinct role. Message includes the ingredient or family name.
- Produces: `IngredientClassificationCheck::PANTRY_STAPLES` → frozen array of the 31 names in Global Constraints.

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"
require "csv"

class IngredientClassificationCheckTest < ActiveSupport::TestCase
  def row(name, family, role) = { "ingredient_name" => name, "family_name" => family, "role" => role }

  test "valid rows have no errors" do
    assert_empty IngredientClassificationCheck.errors([row("chicken", "chicken meat", "protein")])
  end

  test "blank and unknown roles are errors" do
    errors = IngredientClassificationCheck.errors([row("a", "f1", ""), row("b", "f2", "meat")])
    assert_equal 2, errors.size
    assert errors.any? { _1.include?("a") } && errors.any? { _1.include?("b") }
  end

  test "inconsistent roles within a family are an error" do
    errors = IngredientClassificationCheck.errors([row("eggs", "whole eggs", "protein"), row("egg", "whole eggs", "dairy")])
    assert errors.any? { _1.include?("whole eggs") }
  end

  test "real CSV passes the check" do
    rows = CSV.read(Rails.root.join("db/data/ingredient_classification.csv"), headers: true)
    assert_empty IngredientClassificationCheck.errors(rows)
  end

  test "real CSV staples are exactly the agreed list" do
    rows = CSV.read(Rails.root.join("db/data/ingredient_classification.csv"), headers: true)
    staples = rows.select { _1["is_pantry_staple"] == "true" }.map { _1["ingredient_name"] }
    assert_equal IngredientClassificationCheck::PANTRY_STAPLES.sort, staples.sort
  end

  test "eggs are protein and not staples" do
    rows = CSV.read(Rails.root.join("db/data/ingredient_classification.csv"), headers: true)
    eggs = rows.select { _1["family_name"] == "whole eggs" }
    assert eggs.any?
    assert eggs.all? { _1["role"] == "protein" && _1["is_pantry_staple"] == "false" }
  end
end
```

- [ ] **Step 2: Run, verify fail**

Run: `bin/rails test test/services/ingredient_classification_check_test.rb`
Expected: FAIL — `uninitialized constant IngredientClassificationCheck`.

- [ ] **Step 3: Add `Ingredient::ROLES` and implement `IngredientClassificationCheck`** (module with `errors` and `PANTRY_STAPLES`).

- [ ] **Step 4: Update the CSV.** Use Ruby's `CSV` (fields contain quoted commas — no awk/sed). Add header `role` as the last column; assign one role per `family_name` (573 families, 949 rows). Classification guide (Spec table first, then these calls for things it doesn't list):
  - `protein`: meat, poultry, fish, seafood, eggs, tofu/tempeh, beans, lentils, chickpeas, peas-as-pulses
  - `starch`: rice, pasta, noodles, potatoes and other tubers, bread, tortillas/wraps, pastry, grains (couscous, quinoa, oats, bulgur), all flours
  - `produce`: vegetables and fruit (fresh, frozen, canned, dried)
  - `dairy`: milk, cream, cheese, yogurt (butter → `seasoning`, as a cooking fat)
  - `aromatic`: onions, shallots, leeks, scallions, garlic, ginger, fresh chiles, fresh herbs, lemongrass
  - `seasoning`: spices, dried herbs, salt/pepper, oils/fats, sugars/syrups/honey, sauces, pastes, stocks, vinegars, alcohol, nuts/seeds, chocolate, baking agents, water
  
  Set `is_pantry_staple` to `true` exactly for `PANTRY_STAPLES`, `false` otherwise. Write every non-obvious call (anything not plainly in the guide, e.g. nuts, coconut milk, paneer, egg yolks) to the commit message body as `family → role` lines for the PR.

- [ ] **Step 5: Run, verify pass**

Run: `bin/rails test test/services/ingredient_classification_check_test.rb` → PASS.
Run: `bin/rubocop app/services/ingredient_classification_check.rb app/models/ingredient.rb` → no offenses.

- [ ] **Step 6: Commit**

```bash
git add app/services/ingredient_classification_check.rb app/models/ingredient.rb db/data/ingredient_classification.csv test/services/ingredient_classification_check_test.rb
git commit   # message: "Add ingredient roles and trim pantry staples" + borderline role calls
```

---

### Task 2: Persist roles (seed import + data migration for existing DBs)

**Files:**
- Create: `db/migrate/<ts>_add_role_to_ingredients.rb` (`add_column :ingredients, :role, :string`)
- Create: `app/services/ingredient_role_staple_sync.rb`
- Create: `db/migrate/<ts+1>_apply_ingredient_roles_and_staples.rb`
- Modify: `app/services/recipe_data_import_service.rb` (`validate_data`, `import_ingredient_classifications`, `validate_ingredient_results`)
- Modify: `db/schema.rb` (via `bin/rails db:migrate`)
- Test: `test/services/ingredient_role_staple_sync_test.rb`

**Interfaces:**
- Consumes: `IngredientClassificationCheck.errors(rows)`.
- Produces: `ingredients.role` (string, nullable).
- Produces: `IngredientRoleStapleSync.new(rows = <CSV from db/data>).call -> Integer` (number of ingredients updated). Updates only `role` and `is_pantry_staple`, by `ingredient_name`; raises (`KeyError`/`RuntimeError` naming the ingredient) if a row's ingredient isn't in the DB; raises if `IngredientClassificationCheck.errors` is non-empty. Runs in one transaction.

- [ ] **Step 1: Generate and run the schema migration** — `bin/rails g migration AddRoleToIngredients role:string && bin/rails db:migrate`. Expected: `db/schema.rb` shows `t.string "role"` on `ingredients`.

- [ ] **Step 2: Write failing tests**

```ruby
require "test_helper"

class IngredientRoleStapleSyncTest < ActiveSupport::TestCase
  def row(name, family, role, staple) =
    { "ingredient_name" => name, "family_name" => family, "role" => role, "is_pantry_staple" => staple.to_s }

  test "sets role and staple flag only" do
    onion = Ingredient.create!(name: "onion", is_pantry_staple: true, relationship_type: "canonical")
    IngredientRoleStapleSync.new([row("onion", "onions", "aromatic", false)]).call
    onion.reload
    assert_equal "aromatic", onion.role
    refute onion.is_pantry_staple
    assert_equal "canonical", onion.relationship_type
  end

  test "raises when an ingredient is missing from the DB" do
    assert_raises(StandardError) { IngredientRoleStapleSync.new([row("ghost", "g", "protein", false)]).call }
  end

  test "raises on invalid roles and changes nothing" do
    egg = Ingredient.create!(name: "egg")
    assert_raises(StandardError) { IngredientRoleStapleSync.new([row("egg", "whole eggs", "meat", false)]).call }
    assert_nil egg.reload.role
  end
end
```

- [ ] **Step 3: Run, verify fail** — `bin/rails test test/services/ingredient_role_staple_sync_test.rb` → FAIL, uninitialized constant.

- [ ] **Step 4: Implement `IngredientRoleStapleSync`.**

- [ ] **Step 5: Data migration** `ApplyIngredientRolesAndStaples`: same shape as `db/migrate/20261124162827_import_recipe_data.rb` — `say` and return when `Ingredient.none?`; else `IngredientRoleStapleSync.new.call`; `down` raises `ActiveRecord::IrreversibleMigration`.

- [ ] **Step 6: Seed import path.** In `RecipeDataImportService`: `validate_data` raises `"Invalid ingredient roles: #{errors}"` when `IngredientClassificationCheck.errors(@ingredient_rows)` is non-empty; `import_ingredient_classifications` sets `role: row["role"]`; `validate_ingredient_results` also requires `ingredient.role == row["role"]`.

- [ ] **Step 7: Verify**

Run: `bin/rails test` → all pass.
Run: `bin/rails db:migrate` on the dev DB → migration completes; then `bin/rails runner 'puts Ingredient.where(role: nil).count, Ingredient.where(is_pantry_staple: true).count'` → `0` and `31`.
Run: `env RAILS_ENV=test bin/rails db:seed:replant` (network) → ends with "All import validations passed!".

- [ ] **Step 8: Commit** all files above + `db/schema.rb`: "Persist ingredient roles and staples".

---

### Task 3: Weighted scoring in `RecipeMatcher`

**Files:**
- Modify: `app/services/recipe_matcher.rb`
- Test: `test/services/recipe_matcher_test.rb`

**Interfaces:**
- Consumes: `Ingredient#role`, `Ingredient#is_pantry_staple`.
- Produces: constants `RecipeMatcher::ROLE_WEIGHTS` (`{"protein"=>5, "starch"=>3, "produce"=>2, "dairy"=>2, "aromatic"=>1, "seasoning"=>1}`), `DEFAULT_WEIGHT = 1`, `RELATED_MATCH_FACTOR = 0.75`, `MISSING_PENALTY = 0.5`.
- Produces: `RecipeMatcher.new(ingredient_ids, meal_type: nil).call -> Array<Hash>` (≤3), each hash has all current keys plus `score: Float`. Sort: `-score`, `additional_ingredient_count`, `-exact_matching_count`, `recipe.id`.

Test helpers (top of the test class; reused by Task 4):

```ruby
def ing(name, role:, staple: false, family: nil, equivalence: nil, review: false)
  Ingredient.create!(name:, role:, is_pantry_staple: staple, ingredient_family: family,
                     equivalence_key: equivalence, review_needed: review)
end

def recipe(name, *ingredients, meal_types: %w[lunch dinner], eligible: true)
  Recipe.create!(name:, meal_types:, recommendation_eligible: eligible).tap do |r|
    ingredients.each { |i| r.measurements.create!(ingredient: i) }
  end
end

def names(ids, **opts) = RecipeMatcher.new(ids.map(&:id), **opts).call.map { _1[:recipe].name }
```

- [ ] **Step 1: Write failing tests** (each builds its own records):
  - `"protein-and-starch dish beats onion-only dish with fewer missing"` — chicken(protein), rice(starch), onion(aromatic), chorizo(protein), peppers(produce), stock(seasoning), paprika(seasoning), beef(protein). Recipe A = chicken, rice, onion, chorizo, peppers, stock, paprika; Recipe B = onion, beef. `names([chicken, rice, onion])` first element is A; A's `score` == `4.5`, B's == `-1.5`.
  - `"lighter missing ingredients win among equal matches"` — two recipes using chicken; one also needs parsley(aromatic), the other needs pork(protein) → parsley one first.
  - `"staples never count as missing"` — recipe = chicken + salt(seasoning, staple); result `missing_count` counts salt but `additional_ingredient_count == 0` and `score == 5.0`.
  - `"related match scores 0.75 of the weight"` — family F (`IngredientFamily.create!(name: "chicken meat")`); thighs(protein, F, equivalence: 1) selected, breast(protein, F, equivalence: 2) in recipe → `score == 3.75`, `related_matching_count == 1`.
  - `"review_needed blocks equivalence and family matching"` — as above but breast `review: true` → recipe not returned.
  - `"meal type filter and eligibility still apply"` — dessert-only recipe excluded for `meal_type: "lunch"`; `eligible: false` recipe never returned.
  - `"ingredient with no role weighs 1"` — recipe with chicken and mystery(role nil, selected) → `score == 6.0` when both selected.
  - Review Focus: `"blank and unknown ids return empty"` (`RecipeMatcher.new(["", "999999"]).call == []`); `"duplicate measurement counts once"` (recipe with chicken twice → `score == 5.0`, `matching_count == 1`); `"two family members used once each"` (thighs + breast selected, recipe has breast + thighs → `matching_count == 2`, both exact); `"staples-only selection still returns recipes"` (select butter(seasoning, staple) → recipe using butter returned, `score == 1.0`).

- [ ] **Step 2: Run, verify fail** — `bin/rails test test/services/recipe_matcher_test.rb` → score assertions FAIL (`score` key missing / wrong order).

- [ ] **Step 3: Implement** the constants, a private `weight(ingredient)` (`ROLE_WEIGHTS.fetch(role, DEFAULT_WEIGHT)`), the score in the per-recipe hash, and the new sort. Keep matching logic as is. Split `call` into private methods as needed to satisfy rubocop's method-length rules.

- [ ] **Step 4: Verify** — `bin/rails test test/services/recipe_matcher_test.rb` → PASS; `bin/rubocop app/services/recipe_matcher.rb` → no offenses.

- [ ] **Step 5: Commit** — "Rank recipes by role-weighted score".

---

### Task 4: Filling-first for meal-sized requests

**Files:**
- Modify: `app/services/recipe_matcher.rb`
- Modify: `CLAUDE.md` (the "Ingredient matching" paragraph: describe roles, weighted score, filling-first, trimmed staples)
- Test: `test/services/recipe_matcher_test.rb`

**Interfaces:**
- Consumes: Task 3 score and sort.
- Produces: `RecipeMatcher::MEAL_SIZED_TYPES = %w[breakfast lunch dinner any]`; each result hash adds `filling: Boolean`. For meal-sized (or blank) `meal_type`: stable partition of the sorted candidates into filling then non-filling, then `first(3)`. For snack/dessert: no partition.

- [ ] **Step 1: Write failing tests** (use Task 3 helpers):
  - `"lunch fallback prefers filling meal over salad"` — selected: salmon(protein) not in any recipe, plus tomato(produce), cucumber(produce), lettuce(produce). Salad = tomato, cucumber, lettuce (score 6.0, non-filling). Stew = tomato, potatoes(starch) (score `2 − 1.5 = 0.5`, filling). `names([salmon, tomato, cucumber, lettuce], meal_type: "lunch").first == "Stew"`.
  - `"non-filling fills remaining slots"` — same data → result is `["Stew", "Salad"]`.
  - `"snack ignores the filling rule"` — both recipes `meal_types: %w[snack]`, `meal_type: "snack"` → Salad first.
  - Review Focus: `"nil meal type behaves like any"` — same data, `meal_type: nil` and `meal_type: "any"` both return `["Stew", "Salad"]`.
  - `"filling flag reported"` — Stew result `filling == true`, Salad `false`.

- [ ] **Step 2: Run, verify fail** — `bin/rails test test/services/recipe_matcher_test.rb` → new tests FAIL.

- [ ] **Step 3: Implement** `filling?(recipe_ingredients)` (any role in `%w[protein starch]`), the `filling` key, and the partition.

- [ ] **Step 4: Update CLAUDE.md** ingredient-matching paragraph to match the new behaviour (one short paragraph).

- [ ] **Step 5: Verify** — `bin/rails test` → all PASS; `bin/rubocop` → no offenses.

- [ ] **Step 6: Commit** — "Prefer filling recipes for meal-sized requests".

---

### Task 5: Tune against real data and record before/after

**Files:**
- Create (scratchpad, not committed): `match_report.rb` runner script
- Possibly modify: constants in `app/services/recipe_matcher.rb`

- [ ] **Step 1: Write the report script** — for each basket print the top 3 with `score`, `filling`, `additional_ingredient_count` and missing ingredient names. Baskets (looked up by `Ingredient.where(name: …)`), each with `meal_type: "any"` and `"lunch"`:
  `chicken, rice, onion` · `beef, potatoes, carrots` · `eggs, milk, flour, butter` · `salmon, lemon, spinach` · `tofu, broccoli` · `pasta, tomatoes, garlic` · `chickpeas, spinach, onion`.

- [ ] **Step 2: Run on the migrated dev DB** — `bin/rails runner <scratchpad>/match_report.rb`. Check against the spec decisions: the selected protein appears in #1 whenever any eligible recipe uses it; no non-filling dish in a meal-sized top 3 while ≥3 filling candidates exist; #1 needs no more extra non-staple items than today's #1 (spec table: 5 / 3 / 0).

- [ ] **Step 3: If a check fails,** adjust only `MISSING_PENALTY` / `RELATED_MATCH_FACTOR` / `ROLE_WEIGHTS`, re-run Task 3–4 tests (update the numeric score assertions consistently if a constant changes), and re-run the report.

- [ ] **Step 4: Save the report output** for the PR description (before = spec table, after = this output). Commit any constant change: "Tune matcher weights against real baskets".

- [ ] **Step 5: Full CI** — `bin/ci` → all steps green.
