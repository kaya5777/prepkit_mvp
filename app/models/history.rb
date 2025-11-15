class History < ApplicationRecord
  belongs_to :user, optional: true
  has_many :question_answers, dependent: :destroy

  validates :content, presence: true

  # 一覧表示用: 大きなテキストフィールドを除外
  scope :for_listing, -> {
    select(column_names - ['job_description', 'memo', 'stage_1_memo', 'stage_2_memo', 'stage_3_memo'])
  }

  # マークダウンコードブロック記法を除去
  def clean_content
    content.to_s.gsub(/```json\s*/, "").gsub(/```\s*$/, "").strip
  end

  # JSONパース結果を返す（パース失敗時はnil）
  def parsed_content
    JSON.parse(clean_content, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  # パース済みコンテンツがHashかどうか
  def valid_json_content?
    parsed_content.is_a?(Hash)
  end
end
