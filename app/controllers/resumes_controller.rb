class ResumesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume, only: [:show, :destroy, :download]

  def index
    @resumes = current_user.resumes.latest_first.includes(:resume_analyses, original_file_attachment: :blob)
  end

  def show
    unless @resume.analyzed?
      redirect_to resumes_path, alert: "この職務経歴書はまだ分析中または分析されていません"
      return
    end

    @analyses = @resume.resume_analyses.order(:category)
  end

  def new
    @resume = current_user.resumes.build
  end

  def create
    @resume = current_user.resumes.build(resume_params)

    if @resume.save
      begin
        ResumeAnalysisService.call(@resume)
        redirect_to resume_path(@resume), notice: "職務経歴書の分析が完了しました"
      rescue ResumeAnalysisService::AnalysisError => e
        @resume.destroy
        flash.now[:alert] = e.message
        @resume = current_user.resumes.build
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @resume.destroy
    redirect_to resumes_path, notice: "職務経歴書を削除しました"
  end

  def download
    unless @resume.analyzed?
      redirect_to resumes_path, alert: "この職務経歴書はまだ分析されていません"
      return
    end

    format = params[:format] || "pdf"
    export_service = ResumeExportService.new(@resume)
    filename_base = "職務経歴書_改善版_#{Time.current.strftime('%Y%m%d')}"

    if format == "docx"
      send_data export_service.export_as_docx,
                filename: "#{filename_base}.docx",
                type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                disposition: "attachment"
    else
      redirect_to resume_path(@resume), alert: "対応していないフォーマットです"
    end
  rescue => e
    Rails.logger.error "Resume export error: #{e.message}"
    redirect_to resume_path(@resume), alert: "ダウンロードに失敗しました"
  end

  private

  def set_resume
    @resume = current_user.resumes.find(params[:id])
  end

  def resume_params
    params.require(:resume).permit(:original_file)
  end
end
