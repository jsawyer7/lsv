ActiveRecord::Schema[7.0].define(version: 2025_04_16_204800) do
  enable_extension "plpgsql"

  create_table "claims", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content"
    t.text "evidence"
    t.string "result"
    t.text "reasoning"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_claims_on_user_id"
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

  add_foreign_key "claims", "users"
end
