class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :google_oauth2
  skip_before_action :authenticate_user!, raise: false

  def google_oauth2
    Rails.logger.info "=== OAuth Callback Started ==="
    Rails.logger.info "Auth data present: #{request.env['omniauth.auth'].present?}"

    @user = User.from_omniauth(request.env['omniauth.auth'])

    Rails.logger.info "User persisted: #{@user.persisted?}"
    Rails.logger.info "User errors: #{@user.errors.full_messages}" unless @user.persisted?

    if @user.persisted?
      Rails.logger.info "Signing in user: #{@user.email}"
      sign_in @user, event: :authentication
      set_flash_message(:notice, :success, kind: 'Google') if is_navigational_format?
      redirect_to root_path
    else
      Rails.logger.error "Failed to persist user: #{@user.errors.full_messages}"
      session['devise.google_data'] = request.env['omniauth.auth'].except(:extra)
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def failure
    redirect_to root_path
  end
end
