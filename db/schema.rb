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

ActiveRecord::Schema[7.0].define(version: 2025_09_18_160653) do
  # These are extensions that must be enabled in order to support this database
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

  create_table "canon_book_inclusions", id: false, force: :cascade do |t|
    t.bigint "canon_id", null: false
    t.string "work_code", null: false
    t.string "include_from"
    t.string "include_to"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canon_id", "work_code"], name: "index_canon_book_inclusions_on_canon_id_and_work_code", unique: true
    t.index ["canon_id"], name: "index_canon_book_inclusions_on_canon_id"
  end

  create_table "canon_maps", id: false, force: :cascade do |t|
    t.string "canon_id", limit: 64, null: false
    t.string "unit_id", limit: 26, null: false
    t.integer "sequence_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canon_id", "unit_id"], name: "idx_canon_maps_primary", unique: true
  end

  create_table "canon_work_preferences", id: false, force: :cascade do |t|
    t.bigint "canon_id", null: false
    t.string "work_code", null: false
    t.string "foundation_code"
    t.string "numbering_system_code"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canon_id", "work_code"], name: "index_canon_work_preferences_on_canon_id_and_work_code", unique: true
    t.index ["canon_id"], name: "index_canon_work_preferences_on_canon_id"
  end

  create_table "canons", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.string "domain_code"
    t.text "description"
    t.boolean "is_official"
    t.integer "display_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "families_for_foundations", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.string "domain"
    t.text "description"
    t.integer "display_order"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "families_seed", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "follows", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "followed_user", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "followed_user"], name: "index_follows_on_user_id_and_followed_user", unique: true
    t.index ["user_id"], name: "index_follows_on_user_id"
  end

  create_table "foundations_only", force: :cascade do |t|
    t.string "code"
    t.string "title"
    t.string "tradition_code"
    t.string "lang_code"
    t.string "scope"
    t.string "pub_range"
    t.text "citation_hint"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "languages", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.string "iso_639_3"
    t.string "script"
    t.string "direction"
    t.string "language_family"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "master_books", force: :cascade do |t|
    t.string "code"
    t.string "title"
    t.string "family_code"
    t.string "origin_lang"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "numbering_labels", force: :cascade do |t|
    t.integer "numbering_system_id", null: false
    t.string "system_code", null: false
    t.string "label", null: false
    t.string "locale"
    t.string "applies_to"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["numbering_system_id", "system_code"], name: "index_numbering_labels_on_numbering_system_id_and_system_code", unique: true
  end

  create_table "numbering_maps", force: :cascade do |t|
    t.integer "numbering_system_id", null: false
    t.string "unit_id", null: false
    t.string "work_code", null: false
    t.string "l1"
    t.string "l2"
    t.string "l3"
    t.integer "n_book"
    t.integer "n_chapter"
    t.integer "n_verse"
    t.string "n_sub"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["numbering_system_id", "unit_id"], name: "index_numbering_maps_on_numbering_system_id_and_unit_id", unique: true
    t.index ["work_code"], name: "index_numbering_maps_on_work_code"
  end

  create_table "numbering_systems", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_numbering_systems_on_code", unique: true
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

  create_table "source_registries", primary_key: "source_id", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "name", limit: 256, null: false
    t.string "publisher", limit: 256
    t.string "contact", limit: 256
    t.string "license", limit: 256
    t.text "url"
    t.string "version", limit: 64
    t.string "checksum_sha256", limit: 64
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "text_payloads", primary_key: "payload_id", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "unit_id", limit: 26, null: false
    t.string "language", limit: 8, null: false
    t.string "script", limit: 8, null: false
    t.string "edition_id", limit: 128, null: false
    t.string "layer", limit: 32, null: false
    t.text "content", null: false
    t.jsonb "meta"
    t.string "checksum_sha256", limit: 64, null: false
    t.string "source_id", limit: 26, null: false
    t.string "license", limit: 256, null: false
    t.string "version", limit: 64
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id", "edition_id", "layer", "language"], name: "idx_text_payloads_unique", unique: true
  end

  create_table "text_units", primary_key: "unit_id", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "tradition", limit: 32, null: false
    t.string "work_code", limit: 32, null: false
    t.string "division_code", limit: 64, null: false
    t.integer "chapter", null: false
    t.integer "verse", null: false
    t.string "subref", limit: 16
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tradition", "division_code", "chapter", "verse", "subref"], name: "idx_text_units_unique", unique: true
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
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_evidence_usages", "users"
  add_foreign_key "canon_book_inclusions", "canons"
  add_foreign_key "canon_maps", "text_units", column: "unit_id", primary_key: "unit_id"
  add_foreign_key "canon_work_preferences", "canons"
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
  add_foreign_key "numbering_labels", "numbering_systems"
  add_foreign_key "numbering_maps", "numbering_systems"
  add_foreign_key "peers", "users"
  add_foreign_key "peers", "users", column: "peer_id"
  add_foreign_key "text_payloads", "source_registries", column: "source_id", primary_key: "source_id"
  add_foreign_key "text_payloads", "text_units", column: "unit_id", primary_key: "unit_id"
  add_foreign_key "theories", "users"
end
