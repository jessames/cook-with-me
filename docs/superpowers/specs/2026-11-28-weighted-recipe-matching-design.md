# Weighted recipe matching — design

Date: 2026-11-28 · Branch: `recipe-matcher-algo`

## Intent

A user picks the ingredients they have and gets up to 3 recipes. Today those
recipes too often need a lot of extra shopping. The goal: suggestions that
make real use of what the user has — especially their main ingredient — and
need as little else as possible.

### Why it happens today

`RecipeMatcher#call` sorts by `-matching_count` first; extra non-staple
ingredients needed is only the third tie-breaker. Large recipes have more
chances to "use" the user's items, so they win even when they need many more
ingredients. Measured on the current DB (non-staple items still needed):

| Basket | Current #1 | Needs | Better candidate |
|---|---|---|---|
| chicken, rice, onion | Chicken & chorizo rice pot | 5 | — (see below) |
| beef, potatoes, carrots | Jiggs Dinner | 3 | Corned Beef Hash: 1 |
| eggs, milk, flour, butter | Polish Pancakes | 0 | already fine |

Pure "fewest missing" is not the fix: for chicken/rice/onion it surfaces Burek,
which uses only the onion.

## Decisions made with the user

- **Using what the user has comes first**, but ingredients are not equal:
  **a protein counts for more than a supporting item like onion.** Given
  chicken, rice, onion, a chicken-and-rice dish needing 4 more items must beat
  a dish needing 1 more item that uses only the onion.
- This is a **weighting, not a hard filter** (Claude's reading of "weigh
  higher"): if no recipe uses the user's protein, still return the best of the
  rest rather than nothing.
- **Approach: add a `role` to the hand-reviewed ingredient data** (chosen over
  alternatives below).

## Goals

- Rank recipes by a weighted score: reward the user's ingredients a recipe
  uses (weighted by role), penalise the ingredients they'd still need
  (also weighted by role).
- Ingredient roles live in `db/data/ingredient_classification.csv`, reviewed by
  the team like the existing classification columns.
- Real automated tests for `RecipeMatcher` (today there are none).

## Non-goals

- No changes to the results page UI (it shows name + photo only). Showing
  "you'll also need…" is a reasonable follow-up, not part of this.
- No change to `meal_type` filtering, `recommendation_eligible`, or the
  exact/related matching rules (equivalence key, family, `review_needed`).
- **Cook Mode substitution is future work, not built here.** Planned: when a
  user lacks an ingredient or makes a mistake mid-recipe, the LLM assistant
  suggests a substitute and updates the recipe instructions so the dish still
  works (`app/tools/instruction_update_tool.rb`, `messages.proposed_change`
  are the existing scaffolding). Relevance here: a missing minor ingredient is
  recoverable, which is why missing herbs/seasonings are penalised lightly.

## Anti-goals

- Recipes that ignore the user's main ingredient beating ones that use it
  (the Burek case).
- Returning nothing when a weaker match exists.
- Weights hidden in an opaque formula nobody can tune — constants must be named
  and in one place.

## Approaches considered

1. **Role column in the hand-reviewed ingredient data — chosen.** Each
   ingredient gets a role (protein, starch, …) mapped to a weight. Fits the
   existing CSV → import service → data-migration pipeline; accurate and
   tunable. Cost: a review pass over ~949 ingredients / 573 families and a
   schema change.
2. **Infer importance from rarity** (ingredients in fewer recipes weigh more).
   No new data, but rare spices (saffron, tamarind) would outweigh chicken —
   wrong on exactly the user's example. Rejected.
3. **Hard-coded protein list in Ruby.** Fastest, but only expresses
   protein-vs-not and puts reviewed data in code. Rejected.

## Design

### Data

- New column `role` (string, nullable) on `ingredients`.
- New column `role` in `db/data/ingredient_classification.csv`. Every row must
  have a valid role. Roles and starting weights (constants in `RecipeMatcher`,
  e.g. `ROLE_WEIGHTS`):

  | role | weight | examples |
  |---|---|---|
  | `protein` | 5 | chicken meat, ground beef, salmon, tofu, whole eggs, chickpeas, lentils |
  | `starch` | 3 | rice, wheat pasta, potatoes, noodles, bread, tortillas |
  | `produce` | 2 | carrots, spinach, sweet peppers, apples, fresh tomatoes |
  | `dairy` | 2 | dairy milk, cheddar, plain yogurt, dairy cream |
  | `aromatic` | 1 | onions, fresh garlic, ginger, fresh herbs, chiles |
  | `seasoning` | 1 | spices, sauces, stocks, oils, vinegars, sugar |

- Roles are assigned per family in practice: the import validates that all
  rows sharing a `family_name` have the same role.
- Claude drafts roles for every row; the team reviews the CSV diff before
  merge. Borderline calls (eggs in baking, beans as protein vs produce) default
  to the table above and are listed in the PR for review.
- `is_pantry_staple` is unchanged and independent: staples are assumed owned
  and never penalised as missing, whatever their role. A staple the user
  *did* select (e.g. garlic) still earns its normal role weight when a recipe
  uses it. *(Claude's call.)*
- Equivalence keys never cross families, and roles are consistent within a
  family, so a matched pair always shares one role — use the recipe
  ingredient's role.

### Import paths

- `RecipeDataImportService#import_ingredient_classifications` sets `role`;
  `validate_data` rejects missing/unknown roles and inconsistent roles within a
  family; `validate_ingredient_results` checks `role`.
- **Existing databases:** a schema migration adds the column, then a data
  migration applies **only** roles from the CSV (no-op on an empty DB,
  irreversible), following the `ImportRecipeData` pattern. It must **not**
  re-run the full `RecipeDataImportService`: that also re-syncs recipe
  repairs, and `sync_instructions` can destroy instructions that cook-session
  messages reference. If a CSV ingredient is missing from the DB, behave as
  `ImportRecipeData` does (fail loudly). *(Claude's call.)*

### Scoring (`app/services/recipe_matcher.rb`)

Keep the existing matching (exact first, then related within family, each
selected ingredient used at most once). Replace the sort with a score:

```
used_score    = Σ weight(role) over matched recipe ingredients
                (related matches count RELATED_MATCH_FACTOR, start 0.75)
missing_score = Σ weight(role) over missing NON-staple recipe ingredients
score         = used_score − MISSING_PENALTY × missing_score   (start 0.5)
```

- Sort by `-score`, then fewer missing non-staple ingredients, then more exact
  matches, then recipe id (deterministic).
- Keep the rule that a recipe must match at least one selected ingredient.
- Ingredients with no role (e.g. not in the CSV) use a default weight of 1.
- The result hash keeps all existing keys (the view and any callers keep
  working) and adds `score`.

Sanity check with the starting constants, chicken/rice/onion: a chicken-rice
dish missing chorizo (5), peppers (2), stock (1), paprika (1) scores
`9 − 0.5×9 = 4.5`; an onion-only dish missing beef (5) scores
`1 − 0.5×5 = −1.5`. The first wins, as required.

### Tests

- `test/services/recipe_matcher_test.rb` with small hand-built data (fixtures
  or records created in the test — there are no fixtures today). Cover:
  - protein-using recipe beats a recipe that uses only an aromatic, even with
    more missing items (the user's chicken/rice/onion rule);
  - among recipes using the same items, fewer/lighter missing ingredients wins;
  - pantry staples never count as missing;
  - related (family) match scores below exact;
  - `review_needed` ingredients still don't match via equivalence/family;
  - meal type filter and `recommendation_eligible` still apply;
  - no protein match available → still returns the best remaining recipes.
- Import validation tests for the role column (missing / unknown /
  inconsistent within family).

## Left to the builder

- Final constant values: start with the above, then compare top-3 results
  for the three baskets in the table plus a few more of the builder's choosing
  on a seeded dev DB, and adjust if results contradict the decisions above.
  Record the before/after for those baskets in the PR description.
- Whether role weights are a Ruby constant hash or a small config file (keep
  them in one place either way).
- Exact migration names/timestamps and test data setup style.
