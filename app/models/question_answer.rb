class QuestionAnswer < ApplicationRecord
  belongs_to :history
  belongs_to :user, optional: true

  validates :question_index, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :question_text, presence: true
  validates :user_answer, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft scored] }
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  scope :scored, -> { where(status: "scored") }
  scope :drafts, -> { where(status: "draft") }
  scope :for_question, ->(index) { where(question_index: index) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }

  def scored?
    status == "scored"
  end

  def draft?
    status == "draft"
  end

  def good_points
    feedback&.dig("good_points") || []
  end

  def improvements
    feedback&.dig("improvements") || []
  end

  def improvement_example
    feedback&.dig("improvement_example") || ""
  end

  # スコアのグレーディングカラー（グラデーション用）
  def score_gradient_class
    return "bg-gradient-to-br from-gray-400 to-gray-600" if score.nil?

    if score >= 80
      "bg-gradient-to-br from-green-400 to-green-600"
    elsif score >= 60
      "bg-gradient-to-br from-blue-400 to-blue-600"
    else
      "bg-gradient-to-br from-amber-400 to-amber-600"
    end
  end

  # スコアのバッジカラー（背景色+文字色）
  def score_badge_class
    return "bg-gray-100 text-gray-800" if score.nil?

    if score >= 80
      "bg-green-100 text-green-800"
    elsif score >= 60
      "bg-blue-100 text-blue-800"
    else
      "bg-amber-100 text-amber-800"
    end
  end

  # スコアの表示値（nilの場合は0）
  def display_score
    score || 0
  end
end
