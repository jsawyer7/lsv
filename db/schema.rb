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

ActiveRecord::Schema[7.0].define(version: 2025_10_28_232400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_evidence_usages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "used_at"
    t.string "feature_type"
    t.integer "usage_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_ai_evidence_usages_on_user_id"
  end

  create_table "books", force: :cascade do |t|
    t.text "code", null: false
    t.text "std_name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_books_on_code", unique: true
  end

  create_table "canon_books", force: :cascade do |t|
    t.bigint "canon_id", null: false
    t.bigint "book_id", null: false
    t.integer "seq_no", null: false
    t.boolean "included_bool", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_canon_books_on_book_id"
    t.index ["canon_id"], name: "index_canon_books_on_canon_id"
  end

  create_table "canons", force: :cascade do |t|
    t.text "code", null: false
    t.text "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_canons_on_code", unique: true
  end

  create_table "challenges", force: :cascade do |t|
    t.text "text", null: false
    t.string "status", default: "pending"
    t.bigint "claim_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "evidence_id", null: false
    t.index ["claim_id", "user_id"], name: "index_challenges_on_claim_id_and_user_id"
    t.index ["claim_id"], name: "index_challenges_on_claim_id"
    t.index ["evidence_id"], name: "index_challenges_on_evidence_id"
    t.index ["status"], name: "index_challenges_on_status"
    t.index ["user_id"], name: "index_challenges_on_user_id"
  end

  create_table "chargebee_billings", force: :cascade do |t|
    t.string "chargebee_id", null: false
    t.bigint "user_id", null: false
    t.bigint "chargebee_subscription_id", null: false
    t.string "plan_name"
    t.datetime "purchase_date"
    t.datetime "ending_date"
    t.string "status"
    t.decimal "amount", precision: 10, scale: 2
    t.string "currency"
    t.text "description"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chargebee_id"], name: "index_chargebee_billings_on_chargebee_id", unique: true
    t.index ["chargebee_subscription_id"], name: "index_chargebee_billings_on_chargebee_subscription_id"
    t.index ["purchase_date"], name: "index_chargebee_billings_on_purchase_date"
    t.index ["status"], name: "index_chargebee_billings_on_status"
    t.index ["user_id"], name: "index_chargebee_billings_on_user_id"
  end

  create_table "chargebee_plans", force: :cascade do |t|
    t.string "chargebee_id"
    t.string "name"
    t.text "description"
    t.decimal "price"
    t.string "billing_cycle"
    t.string "status"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "chargebee_item_price_id"
  end

  create_table "chargebee_subscriptions", force: :cascade do |t|
    t.string "chargebee_id"
    t.bigint "user_id", null: false
    t.bigint "chargebee_plan_id", null: false
    t.string "status"
    t.datetime "current_term_start"
    t.datetime "current_term_end"
    t.datetime "trial_start"
    t.datetime "trial_end"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chargebee_plan_id"], name: "index_chargebee_subscriptions_on_chargebee_plan_id"
    t.index ["user_id"], name: "index_chargebee_subscriptions_on_user_id"
  end

  create_table "claims", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content"
    t.string "result"
    t.text "reasoning"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "draft", null: false
    t.boolean "publish", default: false, null: false
    t.string "primary_sources", default: [], array: true
    t.string "secondary_sources", default: [], array: true
    t.boolean "fact", default: false
    t.boolean "published", default: false
    t.vector "content_embedding", limit: 3072
    t.string "normalized_content_hash"
    t.text "normalized_content"
    t.text "tradition_hashes"
    t.index ["normalized_content"], name: "index_claims_on_normalized_content"
    t.index ["normalized_content_hash", "user_id"], name: "index_claims_on_normalized_content_hash_and_user_id"
    t.index ["normalized_content_hash"], name: "index_claims_on_normalized_content_hash"
    t.index ["user_id"], name: "index_claims_on_user_id"
  end

  create_table "directions", force: :cascade do |t|
    t.text "code", null: false
    t.text "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_directions_on_code", unique: true
  end

  create_table "evidences", force: :cascade do |t|
    t.bigint "claim_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sources", default: [], array: true
    t.string "verse_reference"
    t.text "original_text"
    t.text "translation"
    t.text "explanation"
    t.string "historical_event"
    t.text "description"
    t.text "relevance"
    t.string "term"
    t.text "definition"
    t.text "etymology"
    t.text "usage_context"
    t.text "premise"
    t.text "reasoning"
    t.text "conclusion"
    t.string "logical_form"
    t.text "normalized_content"
    t.index ["claim_id"], name: "index_evidences_on_claim_id"
    t.index ["normalized_content"], name: "index_evidences_on_normalized_content"
    t.index ["sources"], name: "index_evidences_on_sources", using: :gin
  end

  create_table "follows", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "followed_user", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "followed_user"], name: "index_follows_on_user_id_and_followed_user", unique: true
    t.index ["user_id"], name: "index_follows_on_user_id"
  end

  create_table "languages", force: :cascade do |t|
    t.text "code", null: false
    t.text "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "direction_id"
    t.text "script"
    t.text "font_stack"
    t.boolean "has_joining", default: false
    t.boolean "uses_diacritics", default: false
    t.boolean "has_cantillation", default: false
    t.boolean "has_ayah_markers", default: false
    t.boolean "native_digits", default: false
    t.text "unicode_normalization", default: "NFC"
    t.text "shaping_engine"
    t.boolean "punctuation_mirroring", default: false
    t.index ["code"], name: "index_languages_on_code", unique: true
    t.index ["direction_id"], name: "index_languages_on_direction_id"
  end

  create_table "name_mappings", force: :cascade do |t|
    t.string "internal_id", null: false
    t.string "jewish"
    t.string "christian"
    t.string "muslim"
    t.string "actual"
    t.string "ethiopian"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actual"], name: "index_name_mappings_on_actual"
    t.index ["christian"], name: "index_name_mappings_on_christian"
    t.index ["ethiopian"], name: "index_name_mappings_on_ethiopian"
    t.index ["internal_id"], name: "index_name_mappings_on_internal_id", unique: true
    t.index ["jewish"], name: "index_name_mappings_on_jewish"
    t.index ["muslim"], name: "index_name_mappings_on_muslim"
  end

  create_table "peers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "peer_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["peer_id"], name: "index_peers_on_peer_id"
    t.index ["user_id", "peer_id"], name: "index_peers_on_user_id_and_peer_id", unique: true
    t.index ["user_id"], name: "index_peers_on_user_id"
  end

  create_table "reasonings", force: :cascade do |t|
    t.string "source", null: false
    t.text "response"
    t.string "result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "primary_source", default: false
    t.string "reasonable_type"
    t.bigint "reasonable_id"
    t.text "normalized_content"
    t.index ["normalized_content"], name: "index_reasonings_on_normalized_content"
    t.index ["reasonable_type", "reasonable_id", "source"], name: "index_reasonings_on_reasonable_and_source", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.text "code", null: false
    t.text "name", null: false
    t.text "description"
    t.bigint "language_id", null: false
    t.jsonb "rights_json"
    t.text "provenance"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "text_unit_type_id"
    t.index ["code"], name: "index_sources_on_code", unique: true
    t.index ["language_id"], name: "index_sources_on_language_id"
    t.index ["text_unit_type_id"], name: "index_sources_on_text_unit_type_id"
  end

  create_table "text_contents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "source_id", null: false
    t.bigint "book_id", null: false
    t.bigint "text_unit_type_id", null: false
    t.bigint "language_id", null: false
    t.uuid "parent_unit_id"
    t.integer "unit_group"
    t.integer "unit"
    t.text "content", null: false
    t.string "unit_key", limit: 255, null: false
    t.boolean "canon_catholic", default: false, null: false
    t.boolean "canon_protestant", default: false, null: false
    t.boolean "canon_lutheran", default: false, null: false
    t.boolean "canon_anglican", default: false, null: false
    t.boolean "canon_greek_orthodox", default: false, null: false
    t.boolean "canon_russian_orthodox", default: false, null: false
    t.boolean "canon_georgian_orthodox", default: false, null: false
    t.boolean "canon_western_orthodox", default: false, null: false
    t.boolean "canon_coptic", default: false, null: false
    t.boolean "canon_armenian", default: false, null: false
    t.boolean "canon_ethiopian", default: false, null: false
    t.boolean "canon_syriac", default: false, null: false
    t.boolean "canon_church_east", default: false, null: false
    t.boolean "canon_judaic", default: false, null: false
    t.boolean "canon_samaritan", default: false, null: false
    t.boolean "canon_lds", default: false, null: false
    t.boolean "canon_quran", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_text_contents_on_book_id"
    t.index ["language_id"], name: "index_text_contents_on_language_id"
    t.index ["parent_unit_id"], name: "index_text_contents_on_parent_unit_id"
    t.index ["source_id", "book_id"], name: "index_text_contents_on_source_id_and_book_id"
    t.index ["source_id"], name: "index_text_contents_on_source_id"
    t.index ["text_unit_type_id"], name: "index_text_contents_on_text_unit_type_id"
    t.index ["unit_group", "unit"], name: "index_text_contents_on_unit_group_and_unit"
    t.index ["unit_key"], name: "index_text_contents_on_unit_key", unique: true
  end

  create_table "text_unit_types", force: :cascade do |t|
    t.text "code", null: false
    t.text "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_text_unit_types_on_code", unique: true
  end

  create_table "theories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "in_review", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_theories_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "provider"
    t.string "uid"
    t.string "full_name"
    t.string "avatar_url"
    t.integer "role"
    t.text "about"
    t.string "phone"
    t.bigint "naming_preference_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["naming_preference_id"], name: "index_users_on_naming_preference_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_evidence_usages", "users"
  add_foreign_key "canon_books", "books"
  add_foreign_key "canon_books", "canons"
  add_foreign_key "challenges", "claims"
  add_foreign_key "challenges", "evidences"
  add_foreign_key "challenges", "users"
  add_foreign_key "chargebee_billings", "chargebee_subscriptions"
  add_foreign_key "chargebee_billings", "users"
  add_foreign_key "chargebee_subscriptions", "chargebee_plans"
  add_foreign_key "chargebee_subscriptions", "users"
  add_foreign_key "claims", "users"
  add_foreign_key "evidences", "claims"
  add_foreign_key "follows", "users"
  add_foreign_key "follows", "users", column: "followed_user"
  add_foreign_key "languages", "directions"
  add_foreign_key "peers", "users"
  add_foreign_key "peers", "users", column: "peer_id"
  add_foreign_key "sources", "languages"
  add_foreign_key "sources", "text_unit_types"
  add_foreign_key "text_contents", "books"
  add_foreign_key "text_contents", "languages"
  add_foreign_key "text_contents", "sources"
  add_foreign_key "text_contents", "text_unit_types"
  add_foreign_key "theories", "users"
  add_foreign_key "users", "languages", column: "naming_preference_id"
end
