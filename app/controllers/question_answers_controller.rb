class QuestionAnswersController < ApplicationController
  before_action :set_history
  before_action :set_question_answer, only: [ :show, :destroy ]

  def index
    # タブの選択（デフォルトは「過去の練習回答」）
    @tab = params[:tab] || "my_answers"

    if @tab == "all_answers"
      # みんなの練習回答
      @question_answers = @history.question_answers.scored.recent_first
    else
      # 過去の練習回答（自分のみ）
      @question_answers = @history.question_answers.scored.where(user: current_user).recent_first
    end

    # 質問番号でフィルタリング
    if params[:question_index].present?
      @question_index = params[:question_index].to_i
      @question_answers = @question_answers.for_question(@question_index)
      @question_data = get_question_data(@question_index)
    end

    # ソート
    case params[:sort]
    when "score_desc"
      @question_answers = @question_answers.order(score: :desc, created_at: :desc)
    when "score_asc"
      @question_answers = @question_answers.order(score: :asc, created_at: :desc)
    else
      # デフォルトは最新順
      @question_answers = @question_answers.recent_first
    end

    # 質問リストを取得（フィルター用）
    @questions = get_all_questions
  end

  def new
    @question_index = params[:question_index].to_i
    @question_data = get_question_data(@question_index)

    if @question_data.nil?
      redirect_to history_path(@history), alert: "質問が見つかりません"
      return
    end

    @question_answer = @history.question_answers.build(
      question_index: @question_index,
      question_text: @question_data[:question] || @question_data["question"]
    )
  end

  def create
    @question_answer = @history.question_answers.build(question_answer_params)
    @question_answer.user = current_user
    @question_data = get_question_data(@question_answer.question_index)

    if params[:save_only]
      # 下書き保存
      if @question_answer.save
        redirect_to history_path(@history), notice: "回答を下書き保存しました"
      else
        @question_index = @question_answer.question_index
        render :new, status: :unprocessable_entity
      end
    else
      # 採点実行
      score_and_save
    end
  end

  def show
    # 採点結果表示
  end

  def destroy
    @question_answer.destroy
    redirect_to history_path(@history), notice: "回答を削除しました"
  end

  private

  def set_history
    @history = History.find(params[:history_id])
  end

  def set_question_answer
    @question_answer = @history.question_answers.find(params[:id])
  end

  def question_answer_params
    params.require(:question_answer).permit(:question_index, :question_text, :user_answer)
  end

  def get_question_data(index)
    return nil unless @history.valid_json_content?

    presenter = HistoryPresenter.new(@history)

    # 多段階データの場合
    if presenter.multi_stage?
      # stageパラメータがあればそれを使用、なければ全ステージから探す
      if params[:stage].present?
        stage = params[:stage].to_i
        questions = presenter.questions(stage)
        return questions[index] if questions.is_a?(Array) && questions[index]
      else
        # 全ステージから該当するインデックスの質問を探す
        [ 1, 2, 3 ].each do |stage|
          questions = presenter.questions(stage)
          return questions[index] if questions.is_a?(Array) && questions[index]
        end
      end
      return nil
    end

    # 従来の単一データの場合
    questions = @history.parsed_content[:questions] || @history.parsed_content["questions"]
    return nil unless questions.is_a?(Array) && questions[index]

    questions[index]
  end

  def get_all_questions
    return [] unless @history.valid_json_content?

    presenter = HistoryPresenter.new(@history)

    # 多段階データの場合
    if presenter.multi_stage?
      all_questions = []
      [ 1, 2, 3 ].each do |stage|
        stage_questions = presenter.questions(stage)
        all_questions.concat(stage_questions) if stage_questions.is_a?(Array)
      end
      return all_questions
    end

    # 従来の単一データの場合
    questions = @history.parsed_content[:questions] || @history.parsed_content["questions"]
    return [] unless questions.is_a?(Array)

    questions
  end

  def score_and_save
    begin
      # AIで採点
      result = QuestionAnswerScoringService.call(
        @question_data,
        @question_answer.user_answer,
        @question_data[:level] || @question_data["level"]
      )

      @question_answer.score = result[:score]
      @question_answer.feedback = result.slice(:good_points, :improvements, :improvement_example)
      @question_answer.status = "scored"

      if @question_answer.save
        redirect_to history_question_answer_path(@history, @question_answer), notice: "採点が完了しました"
      else
        @question_index = @question_answer.question_index
        flash.now[:alert] = "保存に失敗しました"
        render :new, status: :unprocessable_entity
      end
    rescue QuestionAnswerScoringService::ScoringError => e
      @question_index = @question_answer.question_index
      @question_data = get_question_data(@question_answer.question_index) if @question_data.nil?
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end
  end
end
