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
end
