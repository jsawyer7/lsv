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

ActiveRecord::Schema[7.0].define(version: 2025_08_21_160928) do
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
  add_foreign_key "challenges", "claims"
  add_foreign_key "challenges", "evidences"
  add_foreign_key "challenges", "users"
  add_foreign_key "claims", "users"
  add_foreign_key "evidences", "claims"
  add_foreign_key "follows", "users"
  add_foreign_key "follows", "users", column: "followed_user"
  add_foreign_key "peers", "users"
  add_foreign_key "peers", "users", column: "peer_id"
  add_foreign_key "theories", "users"
end
