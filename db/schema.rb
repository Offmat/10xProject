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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_184117) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "friendships", force: :cascade do |t|
    t.bigint "addressee_id", null: false
    t.datetime "created_at", null: false
    t.bigint "requester_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["addressee_id"], name: "index_friendships_on_addressee_id"
    t.index ["requester_id", "addressee_id"], name: "index_friendships_on_requester_id_and_addressee_id", unique: true
    t.index ["requester_id"], name: "index_friendships_on_requester_id"
    t.check_constraint "requester_id <> addressee_id", name: "friendships_requester_ne_addressee"
  end

  create_table "game_session_participants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "game_session_id", null: false
    t.string "guest_name"
    t.integer "score", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["game_session_id", "user_id"], name: "index_participants_unique_user_per_session", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["game_session_id"], name: "index_game_session_participants_on_game_session_id"
    t.index ["user_id"], name: "index_game_session_participants_on_user_id"
    t.check_constraint "user_id IS NOT NULL AND guest_name IS NULL OR user_id IS NULL AND guest_name IS NOT NULL", name: "participants_exactly_one_identity"
  end

  create_table "game_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.bigint "game_id", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_game_sessions_on_creator_id"
    t.index ["game_id"], name: "index_game_sessions_on_game_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "bgg_id"
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "imported_at"
    t.integer "max_players"
    t.integer "min_players"
    t.string "name", null: false
    t.integer "play_time_minutes"
    t.string "source", default: "wikidata", null: false
    t.datetime "updated_at", null: false
    t.string "wikidata_id", null: false
    t.integer "year_published"
    t.index ["bgg_id"], name: "index_games_on_bgg_id"
    t.index ["wikidata_id"], name: "index_games_on_wikidata_id", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.datetime "read_at"
    t.string "reason", default: "invitation", null: false
    t.bigint "recipient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["recipient_id", "read_at"], name: "index_notifications_on_recipient_id_and_read_at"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_sessions_on_created_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "friendships", "users", column: "addressee_id"
  add_foreign_key "friendships", "users", column: "requester_id"
  add_foreign_key "game_session_participants", "game_sessions"
  add_foreign_key "game_session_participants", "users"
  add_foreign_key "game_sessions", "games"
  add_foreign_key "game_sessions", "users", column: "creator_id"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "sessions", "users"
end
