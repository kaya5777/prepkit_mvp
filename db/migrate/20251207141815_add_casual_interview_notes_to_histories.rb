class AddCasualInterviewNotesToHistories < ActiveRecord::Migration[7.2]
  def change
    add_column :histories, :casual_interview_notes, :json, default: {}
  end
end
