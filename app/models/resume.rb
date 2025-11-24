class Resume < ApplicationRecord
  belongs_to :user
  has_one_attached :original_file
  has_many :resume_analyses, dependent: :destroy

  validates :status, presence: true, inclusion: { in: %w[draft analyzing analyzed error] }
  validate :acceptable_file

  scope :analyzed, -> { where(status: "analyzed") }
  scope :latest_first, -> { order(created_at: :desc) }

  # ステータス判定
  def draft?
    status == "draft"
  end

  def analyzing?
    status == "analyzing"
  end

  def analyzed?
    status == "analyzed"
  end

  def error?
    status == "error"
  end

  # 総合スコアを計算
  def overall_score
    return nil if resume_analyses.empty?
    resume_analyses.average(:score)&.round
  end

  # カテゴリ別の分析を取得
  def analysis_for(category)
    resume_analyses.find_by(category: category)
  end

  # 改善ポイントを全て取得
  def all_issues
    resume_analyses.flat_map { |a| a.feedback["issues"] || [] }
  end

  # 良い点を全て取得
  def all_good_points
    resume_analyses.flat_map { |a| a.feedback["good_points"] || [] }
  end

  # 改善提案を全て取得
  def all_suggestions
    resume_analyses.flat_map { |a| a.feedback["suggestions"] || [] }
  end

  # 最新の職務経歴書かどうか
  def latest?
    self == user.resumes.latest_first.first
  end

  private

  def acceptable_file
    return unless original_file.attached?

    # ファイルサイズチェック（5MB以下）
    if original_file.blob.byte_size > 5.megabytes
      errors.add(:original_file, "は5MB以下にしてください")
    end

    # ファイル形式チェック
    acceptable_types = [
      "application/pdf",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document", # .docx
      "application/msword" # .doc
    ]

    unless acceptable_types.include?(original_file.blob.content_type)
      errors.add(:original_file, "はPDFまたはWord形式のみ対応しています")
    end
  end
end
