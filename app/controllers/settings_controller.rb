class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @resume = current_user.latest_analyzed_resume
  end

  def update
    @user = current_user

    if @user.update(user_params)
      redirect_to settings_path, notice: "設定を更新しました"
    else
      @resume = current_user.latest_analyzed_resume
      render :show, status: :unprocessable_entity
    end
  end

  def destroy_account
    current_user.destroy
    redirect_to root_path
  end

  private

  def user_params
    params.require(:user).permit(:name)
  end
end
