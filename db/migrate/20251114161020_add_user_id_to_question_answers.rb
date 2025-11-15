class AddUserIdToQuestionAnswers < ActiveRecord::Migration[7.2]
  def change
    add_reference :question_answers, :user, null: true, foreign_key: true
  end
end
