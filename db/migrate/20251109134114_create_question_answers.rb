class CreateQuestionAnswers < ActiveRecord::Migration[7.2]
  def change
    create_table :question_answers do |t|
      t.references :history, null: false, foreign_key: true
      t.integer :question_index, null: false
      t.text :question_text, null: false
      t.text :user_answer, null: false
      t.integer :score
      t.json :feedback
      t.string :status, default: 'draft', null: false

      t.timestamps
    end

    add_index :question_answers, [ :history_id, :question_index ]
  end
end
