class AddUserIdToHistories < ActiveRecord::Migration[7.2]
  def change
    add_reference :histories, :user, null: true, foreign_key: true
  end
end
