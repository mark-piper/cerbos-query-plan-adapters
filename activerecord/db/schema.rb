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

ActiveRecord::Schema[7.0].define(version: 2023_06_10_062929) do
  create_table "resources", id: :string, force: :cascade do |t|
    t.string "a_string"
    t.integer "a_number"
    t.boolean "a_bool"
    t.string "creator_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_resources_on_creator_id"
  end

  create_table "resources_users", id: false, force: :cascade do |t|
    t.string "user_id"
    t.string "resource_id"
    t.index ["resource_id"], name: "index_resources_users_on_resource_id"
    t.index ["user_id"], name: "index_resources_users_on_user_id"
  end

  create_table "user_details", id: :string, force: :cascade do |t|
    t.string "a_string"
    t.string "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_details_on_user_id"
  end

  create_table "users", id: :string, force: :cascade do |t|
    t.string "a_string"
    t.integer "a_number"
    t.boolean "a_bool"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "resources", "users", column: "creator_id"
end
