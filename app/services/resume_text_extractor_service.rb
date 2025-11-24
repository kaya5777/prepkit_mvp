class ResumeTextExtractorService
  class ExtractionError < StandardError; end

  def initialize(resume)
    @resume = resume
  end

  def call
    return nil unless @resume.original_file.attached?

    content_type = @resume.original_file.blob.content_type

    text = case content_type
    when "application/pdf"
      extract_from_pdf
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      extract_from_docx
    when "application/msword"
      raise ExtractionError, ".doc形式は対応していません。.docx形式で再度アップロードしてください。"
    else
      raise ExtractionError, "対応していないファイル形式です: #{content_type}"
    end

    # テキストのクリーニング
    clean_text(text)
  end

  private

  def extract_from_pdf
    require "pdf-reader"

    @resume.original_file.blob.open do |tempfile|
      reader = PDF::Reader.new(tempfile.path)
      text = reader.pages.map(&:text).join("\n\n")

      if text.strip.empty?
        raise ExtractionError, "PDFからテキストを抽出できませんでした。画像PDFの可能性があります。"
      end

      text
    end
  rescue PDF::Reader::MalformedPDFError => e
    raise ExtractionError, "PDFファイルが破損しているか、読み取れない形式です。"
  rescue => e
    Rails.logger.error "PDF extraction error: #{e.message}"
    raise ExtractionError, "PDFの読み取り中にエラーが発生しました。"
  end

  def extract_from_docx
    require "docx"

    @resume.original_file.blob.open do |tempfile|
      doc = Docx::Document.open(tempfile.path)

      # 段落からテキストを抽出
      paragraphs = doc.paragraphs.map(&:text)

      # テーブルからもテキストを抽出
      tables = doc.tables.map do |table|
        table.rows.map do |row|
          row.cells.map(&:text).join("\t")
        end.join("\n")
      end

      text = (paragraphs + tables).join("\n")

      if text.strip.empty?
        raise ExtractionError, "Wordファイルからテキストを抽出できませんでした。"
      end

      text
    end
  rescue Zip::Error => e
    raise ExtractionError, "Wordファイルが破損しているか、読み取れない形式です。"
  rescue => e
    Rails.logger.error "DOCX extraction error: #{e.message}"
    raise ExtractionError, "Wordファイルの読み取り中にエラーが発生しました。"
  end

  def clean_text(text)
    return "" if text.nil?

    text
      .gsub(/\r\n/, "\n")           # 改行コードの統一
      .gsub(/\t+/, " ")              # 連続タブをスペースに
      .gsub(/ +/, " ")               # 連続スペースを単一に
      .gsub(/\n{3,}/, "\n\n")        # 3行以上の空行を2行に
      .strip
  end
end
