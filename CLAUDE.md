# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"Cook With Me" is a Rails 8.1 app (Le Wagon template) where a signed-in user picks the ingredients they have, gets up to 3 matching recipes, then cooks one step by step while chatting with an LLM assistant about the current step. Recipe data comes from TheMealDB plus hand-reviewed classification/repair files in `db/data/`.

Stack: PostgreSQL, Devise (every controller requires login via `ApplicationController`), Hotwire (Turbo + Stimulus via importmap, no Node build), Sprockets + SassC + Bootstrap 5 + Simple Form, `ruby_llm` (OpenAI, `gpt-4.1-mini`, key from `OPENAI_KEY` in `.env` loaded by dotenv). Solid Queue/Cache/Cable and Kamal are present from the Rails defaults.

## Commands

```bash
bin/setup                  # install gems, prepare DB, start server
bin/dev                    # rails server
bin/rails db:seed          # fetch all recipes from TheMealDB (network) + apply db/data imports
bin/ci                     # full CI: rubocop, bundler-audit, importmap audit, brakeman, tests, seed replant
bin/rails test             # all tests (Minitest, parallel)
bin/rails test test/models/recipe_test.rb:12   # single file / single test by line
bin/rubocop                # lint (db/, config/, test/, bin/ are excluded; max line length 120)
bin/brakeman --quiet --no-pager
```

Tests are currently generator stubs and `test/fixtures/` has no YAML fixtures, so `bin/rails test` exercises almost nothing.

## Architecture

**Domain flow** (`config/routes.rb`):
- `pages#home` → ingredient picker (`ingredient_search` Stimulus controller filters an in-page JSON list of ingredients) → `recipes#results` calls `RecipeMatcher`.
- `POST /recipes/:id/cook_sessions` creates a `CookSession` and redirects to the first `Instruction`. `instructions#show` is the step view with prev/next by `instruction_number`.
- `messages#create` (nested under cook session) saves the user message, replays the whole session's history into `RubyLLM.chat`, adds a system prompt + current recipe/step context, stores the assistant reply, and responds via `messages/create.turbo_stream.erb`. Each message is tied to an `instruction_id`. `proposed_change`/`accepted_at` columns and `app/tools/instruction_update_tool.rb` are scaffolding for LLM-proposed recipe edits that isn't wired up yet.
- Destroying a cook session marks the recipe `cooked: true` (that's what `recipes#index` lists as "recent recipes").

**Ingredient matching** (`app/services/recipe_matcher.rb`): only `recommendation_eligible` recipes, optionally filtered by `meal_types` (Postgres array). Each selected ingredient can satisfy at most one recipe ingredient: exact matches first (same id or same `equivalence_key`), then "related" matches (same `ingredient_family_id`, different equivalence key). Ingredients/recipes flagged `review_needed` never match via equivalence/family. Ranking: most matches, then most exact matches, then fewest missing non-pantry-staple ingredients.

**Recipe data pipeline** — the key cross-cutting piece:
1. `db/seeds.rb` pulls recipes a–z from TheMealDB, creates `Recipe`/`Ingredient` (names downcased)/`Measurement`, and splits `strInstructions` into `Instruction` rows, cleaning them with `lib/instruction_cleanup_v1.rb` (strip numbering prefixes, drop standalone step markers) and `lib/reviewed_instruction_cleanup.rb`.
2. `RecipeDataImportService` (run at the end of seeds) applies `db/data/recipe_repairs.json` (new ingredients/recipe fixes), `ingredient_classification.csv` (families, equivalence keys, pantry staples, review flags) and `recipe_classification.csv` (dish role, meal types, eligibility), in one transaction with validation.
3. Existing databases receive the same changes through **data migrations** (e.g. `ImportRecipeData`, `CleanRecipeInstructions`, `ApplyReviewedInstructionEdits`) that no-op on an empty DB and are irreversible. When changing data cleanup, update both the seed path and add a migration for existing DBs.

`reviewed_instruction_edits.json` is keyed by TheMealDB `external_id`; each entry has a SHA-256 checksum of the instruction texts it was reviewed against plus `[row_count, prefix_length]` groups describing how to merge rows. Edits are skipped if the checksum doesn't match, and the migration also skips recipes whose continuation rows already have chat messages.

`rake recipes:export_classification` exports recipes to `db/recipe_classification_export.csv` for (offline) classification that feeds back into `db/data/`.

**Styles**: Le Wagon SCSS layout in `app/assets/stylesheets/` (`config/` for Bootstrap variables, colors, fonts; `components/` and `pages/` each with an `_index.scss` that must import new partials).
