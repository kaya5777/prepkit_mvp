class History < ApplicationRecord
  has_many :question_answers, dependent: :destroy

  validates :content, presence: true

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
