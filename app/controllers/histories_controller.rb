class HistoriesController < ApplicationController
  before_action :set_history, only: %i[show edit update destroy]

  def index
    @histories = History.order(asked_at: :desc)
  end

  def show
    @presenter = HistoryPresenter.new(@history)
  end

  def new
    @history = History.new
  end

  def edit
    @presenter = HistoryPresenter.new(@history)
  end

  def create
    @history = History.new(history_params)
    @history.asked_at ||= Time.current
    if @history.save
      redirect_to @history, notice: "履歴を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @history.update(history_params)
      redirect_to @history, notice: "履歴を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @history.destroy
    redirect_to root_path, notice: "履歴を削除しました。"
  end

  private
  def set_history
    @history = History.find(params[:id])
  end

  def history_params
    params.require(:history).permit(:content, :asked_at, :memo, :company_name)
  end
end
