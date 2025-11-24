class ResumeAnalysis < ApplicationRecord
  belongs_to :resume

  CATEGORIES = %w[structure content expression layout].freeze

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  scope :by_category, ->(category) { where(category: category) }

  # カテゴリの日本語名
  def category_name
    case category
    when "structure" then "構成"
    when "content" then "内容"
    when "expression" then "表現"
    when "layout" then "見やすさ"
    else category
    end
  end

  # スコアに応じたグレード
  def grade
    return nil if score.nil?

    case score
    when 90..100 then "S"
    when 80..89 then "A"
    when 70..79 then "B"
    when 60..69 then "C"
    when 0..59 then "D"
    else "D"
    end
  end

  # スコアに応じた色クラス（グラデーション用）
  def score_gradient_class
    return "bg-gradient-to-br from-gray-400 to-gray-600" if score.nil?

    case score
    when 80..100 then "bg-gradient-to-br from-green-400 to-green-600"
    when 60..79 then "bg-gradient-to-br from-blue-400 to-blue-600"
    else "bg-gradient-to-br from-amber-400 to-amber-600"
    end
  end

  # スコアに応じたバッジ色クラス
  def score_badge_class
    return "bg-gray-100 text-gray-800" if score.nil?

    case score
    when 80..100 then "bg-green-100 text-green-800"
    when 60..79 then "bg-blue-100 text-blue-800"
    else "bg-amber-100 text-amber-800"
    end
  end

  # フィードバックのアクセサ
  def issues
    feedback["issues"] || []
  end

  def good_points
    feedback["good_points"] || []
  end

  def suggestions
    feedback["suggestions"] || []
  end

  def examples
    feedback["examples"] || []
  end
end
