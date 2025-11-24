class AddMatchFieldsToHistories < ActiveRecord::Migration[7.2]
  def change
    add_column :histories, :match_score, :integer
    add_column :histories, :match_analysis, :json, default: {}
    add_column :histories, :match_rank, :string  # S/A/B/C/D ランク

    add_index :histories, :match_score
    add_index :histories, :match_rank
  end
end
