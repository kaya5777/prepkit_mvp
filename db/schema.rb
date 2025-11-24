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

ActiveRecord::Schema[7.2].define(version: 2025_11_23_223819) do
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

  create_table "histories", force: :cascade do |t|
    t.text "content"
    t.datetime "asked_at"
    t.text "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "job_description"
    t.string "company_name"
    t.text "stage_1_memo"
    t.text "stage_2_memo"
    t.text "stage_3_memo"
    t.integer "user_id"
    t.integer "match_score"
    t.json "match_analysis", default: {}
    t.string "match_rank"
    t.index ["asked_at"], name: "index_histories_on_asked_at"
    t.index ["match_rank"], name: "index_histories_on_match_rank"
    t.index ["match_score"], name: "index_histories_on_match_score"
    t.index ["user_id", "asked_at"], name: "index_histories_on_user_id_and_asked_at"
    t.index ["user_id"], name: "index_histories_on_user_id"
  end

  create_table "question_answers", force: :cascade do |t|
    t.integer "history_id", null: false
    t.integer "question_index", null: false
    t.text "question_text", null: false
    t.text "user_answer", null: false
    t.integer "score"
    t.json "feedback"
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["created_at"], name: "index_question_answers_on_created_at"
    t.index ["history_id", "question_index"], name: "index_question_answers_on_history_id_and_question_index"
    t.index ["history_id", "status"], name: "index_question_answers_on_history_id_and_status"
    t.index ["history_id", "user_id", "status"], name: "index_question_answers_on_history_id_and_user_id_and_status"
    t.index ["history_id"], name: "index_question_answers_on_history_id"
    t.index ["user_id"], name: "index_question_answers_on_user_id"
  end

  create_table "resume_analyses", force: :cascade do |t|
    t.integer "resume_id", null: false
    t.string "category", null: false
    t.integer "score"
    t.json "feedback", default: {}
    t.text "improved_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_resume_analyses_on_category"
    t.index ["resume_id", "category"], name: "index_resume_analyses_on_resume_id_and_category", unique: true
    t.index ["resume_id"], name: "index_resume_analyses_on_resume_id"
  end

  create_table "resumes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "raw_text"
    t.text "summary"
    t.string "status", default: "draft", null: false
    t.datetime "analyzed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_resumes_on_status"
    t.index ["user_id", "created_at"], name: "index_resumes_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_resumes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "histories", "users"
  add_foreign_key "question_answers", "histories"
  add_foreign_key "question_answers", "users"
  add_foreign_key "resume_analyses", "resumes"
  add_foreign_key "resumes", "users"
end
