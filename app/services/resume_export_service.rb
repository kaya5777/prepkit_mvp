class ResumeExportService
  class ExportError < StandardError; end

  def initialize(resume)
    @resume = resume
  end

  def export_as_pdf
    require "prawn"

    pdf = Prawn::Document.new(page_size: "A4", margin: [ 40, 40, 40, 40 ])

    # 日本語フォントの設定（IPAexゴシック）
    ipa_font_path = Rails.root.join("app", "assets", "fonts", "ipaexg.ttf")

    if File.exist?(ipa_font_path)
      pdf.font_families.update("IPAGothic" => { normal: ipa_font_path.to_s })
      pdf.font "IPAGothic"
    else
      raise ExportError, "日本語フォントがインストールされていません"
    end

    # 改善版テキスト
    improved_text = @resume.resume_analyses.first&.improved_text || @resume.raw_text

    # ヘッダー
    pdf.text "職務経歴書（改善版）", size: 24, align: :center
    pdf.move_down 10
    pdf.text "AI分析による改善提案を適用", size: 10, align: :center
    pdf.move_down 30

    # 改善版テキスト
    if improved_text.present?
      improved_text.split("\n").each do |line|
        pdf.text line, size: 11, leading: 4
      end
    end

    # フッター
    pdf.move_down 30
    pdf.stroke_horizontal_rule
    pdf.move_down 10
    pdf.text "※このドキュメントはAIによる改善提案を適用したものです。", size: 8
    pdf.text "  実際の提出前に内容を確認し、必要に応じて修正してください。", size: 8

    pdf.render
  end

  def export_as_docx
    require "zip"

    # 改善版テキストを取得
    improved_text = @resume.resume_analyses.first&.improved_text || @resume.raw_text

    # docxファイルを生成（OpenXML形式）
    build_docx(improved_text)
  end

  private

  def build_docx(content)
    require "zip"

    buffer = StringIO.new
    buffer.set_encoding("BINARY")

    Zip::OutputStream.write_buffer(buffer) do |zos|
      # [Content_Types].xml
      zos.put_next_entry("[Content_Types].xml")
      zos.write content_types_xml

      # _rels/.rels
      zos.put_next_entry("_rels/.rels")
      zos.write rels_xml

      # word/_rels/document.xml.rels
      zos.put_next_entry("word/_rels/document.xml.rels")
      zos.write document_rels_xml

      # word/document.xml
      zos.put_next_entry("word/document.xml")
      zos.write document_xml(content)

      # word/styles.xml
      zos.put_next_entry("word/styles.xml")
      zos.write styles_xml
    end

    buffer.rewind
    buffer.read
  end

  def content_types_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
      </Types>
    XML
  end

  def rels_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
      </Relationships>
    XML
  end

  def document_rels_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
      </Relationships>
    XML
  end

  def document_xml(content)
    paragraphs = content.to_s.split("\n").map do |line|
      escaped = escape_xml(line)
      if line.strip.start_with?("■")
        # 見出し
        "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:t>#{escaped}</w:t></w:r></w:p>"
      elsif line.strip.empty?
        "<w:p><w:r><w:t></w:t></w:r></w:p>"
      else
        "<w:p><w:r><w:t>#{escaped}</w:t></w:r></w:p>"
      end
    end.join("\n")

    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:pPr><w:jc w:val="center"/></w:pPr>
            <w:r>
              <w:rPr><w:b/><w:sz w:val="48"/></w:rPr>
              <w:t>職務経歴書（改善版）</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:pPr><w:jc w:val="center"/></w:pPr>
            <w:r>
              <w:rPr><w:color w:val="666666"/><w:sz w:val="20"/></w:rPr>
              <w:t>AI分析による改善提案を適用したバージョンです</w:t>
            </w:r>
          </w:p>
          <w:p><w:r><w:t></w:t></w:r></w:p>
          #{paragraphs}
          <w:p><w:r><w:t></w:t></w:r></w:p>
          <w:p>
            <w:r>
              <w:rPr><w:color w:val="999999"/><w:sz w:val="18"/></w:rPr>
              <w:t>※このドキュメントはAIによる改善提案を適用したものです。</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:r>
              <w:rPr><w:color w:val="999999"/><w:sz w:val="18"/></w:rPr>
              <w:t>実際の提出前に内容を確認し、必要に応じて修正してください。</w:t>
            </w:r>
          </w:p>
        </w:body>
      </w:document>
    XML
  end

  def styles_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
          <w:name w:val="Normal"/>
          <w:rPr>
            <w:rFonts w:ascii="Yu Gothic" w:hAnsi="Yu Gothic" w:eastAsia="Yu Gothic"/>
            <w:sz w:val="22"/>
          </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading1">
          <w:name w:val="Heading 1"/>
          <w:basedOn w:val="Normal"/>
          <w:rPr>
            <w:b/>
            <w:sz w:val="28"/>
          </w:rPr>
          <w:pPr>
            <w:spacing w:before="240" w:after="120"/>
          </w:pPr>
        </w:style>
      </w:styles>
    XML
  end

  def escape_xml(text)
    text.to_s
        .gsub("&", "&amp;")
        .gsub("<", "&lt;")
        .gsub(">", "&gt;")
        .gsub("\"", "&quot;")
        .gsub("'", "&apos;")
  end
end
