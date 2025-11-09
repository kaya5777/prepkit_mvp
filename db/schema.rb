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

ActiveRecord::Schema[7.2].define(version: 2025_11_09_145120) do
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
    t.index ["history_id", "question_index"], name: "index_question_answers_on_history_id_and_question_index"
    t.index ["history_id"], name: "index_question_answers_on_history_id"
  end

  add_foreign_key "question_answers", "histories"
end
