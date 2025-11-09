class AddStageMemoToHistories < ActiveRecord::Migration[7.2]
  def change
    add_column :histories, :stage_1_memo, :text
    add_column :histories, :stage_2_memo, :text
    add_column :histories, :stage_3_memo, :text
  end
end
