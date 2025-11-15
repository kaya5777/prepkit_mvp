class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_sidebar_histories

  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from JSON::ParserError, with: :render_unprocessable_entity

  # 本番・テストでは予期せぬ例外を 500 に集約（開発はデフォルトのエラーページでデバッグ）
  unless Rails.env.development?
    rescue_from StandardError, with: :render_internal_server_error
  end

  private

  def set_sidebar_histories
    return unless current_user

    @my_sidebar_histories = current_user.histories.order(asked_at: :desc).limit(5)
    @all_sidebar_histories = History.order(asked_at: :desc).limit(5)
  end

  def render_bad_request(exception)
    log_exception(exception)
    if request.format.html?
      flash.now[:alert] = "必須入力が不足しています: #{exception.param}"
      # フォームを持つ画面に戻す（存在しない場合はルートへ）
      if lookup_context.exists?("preparations/new")
        render "preparations/new", status: :bad_request
      else
        redirect_to root_path, alert: flash.now[:alert]
      end
    else
      render file: Rails.public_path.join("400.html"), status: :bad_request, layout: false
    end
  end

  def render_unprocessable_entity(exception)
    log_exception(exception)
    render file: Rails.public_path.join("422.html"), status: :unprocessable_entity, layout: false
  end

  def render_internal_server_error(exception)
    log_exception(exception)
    render file: Rails.public_path.join("500.html"), status: :internal_server_error, layout: false
  end

  def log_exception(exception)
    Rails.logger.error "#{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
  end
end
