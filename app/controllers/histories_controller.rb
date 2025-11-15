class HistoriesController < ApplicationController
  before_action :set_history, only: %i[show edit update destroy]

  def index
    @histories = History.order(asked_at: :desc)
  end

  def show
    @presenter = HistoryPresenter.new(@history)

    # タブの選択（デフォルトは「過去の練習回答」）
    @answers_tab = params[:answers_tab] || "my_answers"

    # 過去の練習回答を取得
    if @answers_tab == "all_answers"
      # みんなの練習回答
      @past_answers = @history.question_answers.scored.order(created_at: :desc).limit(5)
    else
      # 過去の練習回答（自分のみ）
      @past_answers = @history.question_answers.scored.where(user: current_user).order(created_at: :desc).limit(5)
    end
  end

  def new
    @history = History.new
  end

  def edit
    @presenter = HistoryPresenter.new(@history)
  end

  def create
    @history = History.new(history_params)
    @history.user = current_user
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

  def my_histories
    @histories = current_user.histories.order(asked_at: :desc)
  end

  def all_histories
    @histories = History.where("user_id IS NULL OR user_id != ?", current_user.id).order(asked_at: :desc)
  end

  private
  def set_history
    @history = History.find(params[:id])
  end

  def history_params
    params.require(:history).permit(:content, :asked_at, :memo, :company_name, :stage_1_memo, :stage_2_memo, :stage_3_memo)
  end
end
