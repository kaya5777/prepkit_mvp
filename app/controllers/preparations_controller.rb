class PreparationsController < ApplicationController
  def new
  end

  def create
    # 入力検証
    jd = params[:job_description].to_s.strip
    cn = params[:company_name].to_s.strip
    if jd.empty?
      flash.now[:alert] = "求人票の入力は必須です。"
      return render :new, status: :unprocessable_content
    end

    # OpenAI API キー事前チェック
    if ENV["OPENAI_API_KEY"].to_s.strip.empty?
      flash.now[:alert] = "OpenAI の API キーが設定されていません（code: missing_api_key）。管理者にお問い合わせください。"
      return render :new, status: :service_unavailable
    end

    begin
      client = OpenAI::Client.new
      response = client.chat.completions.create(
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: "あなたは面接官です。JSON形式で出力してください。" },
          { role: "user", content: prompt_for(jd) }
        ]
      )

      # OpenAIクライアントのオブジェクト（ChatCompletion）を前提とした取得
      first_choice = response.respond_to?(:choices) ? response.choices&.first : nil
      message = first_choice.respond_to?(:message) ? first_choice.message : (first_choice.is_a?(Hash) ? first_choice[:message] : nil)
      content = message.respond_to?(:content) ? message.content : (message.is_a?(Hash) ? message[:content] : nil)
      if content.blank?
        Rails.logger.error "OpenAI 応答に content がありません: #{response.inspect}"
        flash.now[:alert] = "生成に失敗しました（code: content_blank）。しばらくしてから再度お試しください。"
        return render :new, status: :service_unavailable
      end

      json_string = content.gsub(/\A```json|```|\A```|\Z```/m, "").strip
      @result = JSON.parse(json_string, symbolize_names: true)
      # 履歴も保存
      History.create!(content: content, memo: "", asked_at: Time.current, job_description: jd, company_name: cn)
      render :show
    rescue JSON::ParserError => e
      Rails.logger.error "JSON パース失敗: #{e.message}"
      flash.now[:alert] = "生成結果の形式が不正でした（#{e.message}）。もう一度お試しください。"
      render :new, status: :unprocessable_content
    rescue StandardError => e
      Rails.logger.error "想定外のエラー: #{e.class} #{e.message}"
      if e.class.to_s.include?("AuthenticationError") || e.message.include?("status=>401")
        flash.now[:alert] = "OpenAI への認証に失敗しました（401）。APIキーが未設定または無効です。管理者にお問い合わせください。"
        return render :new, status: :service_unavailable
      end
      flash.now[:alert] = "エラーが発生しました（#{e.class}: #{e.message}）。時間をおいて再度お試しください。"
      render :new, status: :internal_server_error
    end
  end

  private

  def prompt_for(jd)
    <<~PROMPT
    以下の求人票をもとに面接準備キットを生成してください。
    JSON形式で出力してください。

    出力フォーマット:
    {
      "questions": ["質問1", "質問2", ...],
      "star_answers": [
        {"question": "質問1", "situation": "...", "task": "...", "action": "...", "result": "..."}
      ],
      "reverse_questions": ["逆質問1", "逆質問2"],
      "tech_checklist": ["チェック項目1", "チェック項目2"]
    }

    求人票:
    #{jd}
    PROMPT
  end
end
