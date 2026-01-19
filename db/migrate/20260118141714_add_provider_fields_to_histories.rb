class AddProviderFieldsToHistories < ActiveRecord::Migration[7.2]
  def change
    # OpenAI用のカラム
    add_column :histories, :match_score_openai, :integer
    add_column :histories, :match_rank_openai, :string
    add_column :histories, :match_analysis_openai, :json

    # Gemini用のカラム
    add_column :histories, :match_score_gemini, :integer
    add_column :histories, :match_rank_gemini, :string
    add_column :histories, :match_analysis_gemini, :json

    # 既存のカラムはOpenAIのデータとして保持（後方互換性）
    # 後でデータ移行してから削除することもできる
  end
end
