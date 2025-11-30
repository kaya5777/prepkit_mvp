class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_many :histories, dependent: :nullify
  has_many :question_answers, dependent: :nullify
  has_many :resumes, dependent: :destroy

  # 最新の職務経歴書を取得
  def latest_resume
    resumes.order(created_at: :desc).first
  end

  # 分析済みの最新職務経歴書を取得
  def latest_analyzed_resume
    resumes.analyzed.order(created_at: :desc).first
  end

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.name = auth.info.name
      user.avatar_url = auth.info.image
    end
  end
end
