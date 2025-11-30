class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    # Histories indexes
    add_index :histories, :asked_at unless index_exists?(:histories, :asked_at)
    add_index :histories, [ :user_id, :asked_at ] unless index_exists?(:histories, [ :user_id, :asked_at ])

    # Question answers indexes
    add_index :question_answers, :history_id unless index_exists?(:question_answers, :history_id)
    add_index :question_answers, [ :history_id, :question_index ] unless index_exists?(:question_answers, [ :history_id, :question_index ])
    add_index :question_answers, [ :history_id, :status ] unless index_exists?(:question_answers, [ :history_id, :status ])
    add_index :question_answers, [ :history_id, :user_id, :status ] unless index_exists?(:question_answers, [ :history_id, :user_id, :status ])
    add_index :question_answers, :created_at unless index_exists?(:question_answers, :created_at)
  end
end
