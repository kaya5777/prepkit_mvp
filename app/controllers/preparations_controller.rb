class PreparationsController < ApplicationController
  def new
  end

  def create
    # 入力検証
    job_description = params[:job_description].to_s.strip
    company_name = params[:company_name].to_s.strip

    if job_description.empty?
      flash.now[:alert] = "求人票の入力は必須です。"
      return render :new, status: :unprocessable_content
    end

    # URL判定と取得処理
    job_description = fetch_from_url_if_needed(job_description)
    return if performed? # エラー時は既にレンダリング済み

    # InterviewKitGeneratorServiceで生成
    begin
      result = InterviewKitGeneratorService.call(job_description, company_name)
      @result = result[:result]
      render :show
    rescue InterviewKitGeneratorService::APIKeyMissingError => e
      flash.now[:alert] = e.message
      render :new, status: :service_unavailable
    rescue InterviewKitGeneratorService::ContentBlankError => e
      flash.now[:alert] = e.message
      render :new, status: :service_unavailable
    rescue InterviewKitGeneratorService::ParseError => e
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_content
    rescue InterviewKitGeneratorService::AuthenticationError => e
      flash.now[:alert] = e.message
      render :new, status: :service_unavailable
    rescue StandardError => e
      Rails.logger.error "想定外のエラー: #{e.class} #{e.message}"
      flash.now[:alert] = "エラーが発生しました（#{e.class}: #{e.message}）。時間をおいて再度お試しください。"
      render :new, status: :internal_server_error
    end
  end

  private

  def url?(text)
    text.match?(/\A(https?:\/\/)/)
  end

  def fetch_from_url_if_needed(job_description)
    return job_description unless url?(job_description)

    begin
      fetched_content = JobDescriptionFetcherService.call(job_description)
      if fetched_content.empty?
        flash.now[:alert] = "URLから求人情報を取得できませんでした。"
        render :new, status: :unprocessable_content
        return nil
      end
      fetched_content
    rescue JobDescriptionFetcherService::FetchError => e
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_content
      nil
    end
  end
end
