# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_27_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cook_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "recipe_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_cook_sessions_on_recipe_id"
    t.index ["user_id"], name: "index_cook_sessions_on_user_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "recipe_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_favorites_on_recipe_id"
    t.index ["user_id", "recipe_id"], name: "index_favorites_on_user_id_and_recipe_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "ingredient_families", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ingredients", force: :cascade do |t|
    t.string "name"
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "ingredient_family_id"
    t.bigint "equivalence_key"
    t.string "relationship_type"
    t.boolean "review_needed", default: false
    t.boolean "is_pantry_staple", default: false, null: false
    t.index ["ingredient_family_id"], name: "index_ingredients_on_ingredient_family_id"
  end

  create_table "instructions", force: :cascade do |t|
    t.integer "instruction_number"
    t.text "instruction_content"
    t.bigint "recipe_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_instructions_on_recipe_id"
  end

  create_table "measurements", force: :cascade do |t|
    t.bigint "recipe_id", null: false
    t.string "measure_unit"
    t.string "measure_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "ingredient_id", null: false
    t.index ["ingredient_id"], name: "index_measurements_on_ingredient_id"
    t.index ["recipe_id"], name: "index_measurements_on_recipe_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "role"
    t.bigint "cook_session_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "instruction_id", null: false
    t.jsonb "proposed_change"
    t.datetime "accepted_at"
    t.index ["cook_session_id"], name: "index_messages_on_cook_session_id"
    t.index ["instruction_id"], name: "index_messages_on_instruction_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.string "name"
    t.string "image_url"
    t.boolean "cooked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.string "source_category"
    t.string "dish_role"
    t.string "meal_types", default: [], null: false, array: true
    t.boolean "recommendation_eligible", default: false, null: false
    t.boolean "review_needed", default: true, null: false
    t.index ["external_id"], name: "index_recipes_on_external_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "cook_sessions", "recipes"
  add_foreign_key "cook_sessions", "users"
  add_foreign_key "favorites", "recipes"
  add_foreign_key "favorites", "users"
  add_foreign_key "ingredients", "ingredient_families"
  add_foreign_key "instructions", "recipes"
  add_foreign_key "measurements", "ingredients"
  add_foreign_key "measurements", "recipes"
  add_foreign_key "messages", "cook_sessions"
  add_foreign_key "messages", "instructions"
end
