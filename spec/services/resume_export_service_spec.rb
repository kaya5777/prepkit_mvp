require 'rails_helper'

RSpec.describe ResumeExportService do
  let(:user) { create(:user) }
  let(:resume) { create(:resume, user: user, raw_text: "職務経歴\n\n経験1\n経験2") }
  let(:service) { described_class.new(resume) }

  describe "#export_as_pdf" do
    context "when font file exists" do
      before do
        allow(File).to receive(:exist?).and_return(true)
      end

      it "generates PDF document" do
        pdf_data = service.export_as_pdf
        expect(pdf_data).to be_a(String)
        expect(pdf_data).not_to be_empty
      end

      it "includes resume text in PDF" do
        pdf_data = service.export_as_pdf
        expect(pdf_data).to include("%PDF")
      end
    end

    context "when font file does not exist" do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it "raises ExportError" do
        expect {
          service.export_as_pdf
        }.to raise_error(ResumeExportService::ExportError, /日本語フォントがインストールされていません/)
      end
    end
  end

  describe "#export_as_docx" do
    it "generates DOCX document" do
      docx_data = service.export_as_docx
      expect(docx_data).to be_a(String)
      expect(docx_data).not_to be_empty
    end

    it "generates valid ZIP structure" do
      docx_data = service.export_as_docx
      expect(docx_data[0..1]).to eq("PK") # ZIP magic number
    end

    it "includes resume content" do
      docx_data = service.export_as_docx
      # DOCX is a ZIP file containing XML files
      expect(docx_data).to include("document.xml")
    end
  end

  describe "private methods" do
    describe "#escape_xml" do
      it "escapes special XML characters" do
        text = "Test & <tag> \"quote\" 'apostrophe'"
        result = service.send(:escape_xml, text)

        expect(result).to include("&amp;")
        expect(result).to include("&lt;")
        expect(result).to include("&gt;")
        expect(result).to include("&quot;")
        expect(result).to include("&apos;")
      end
    end

    describe "#content_types_xml" do
      it "generates valid content types XML" do
        xml = service.send(:content_types_xml)
        expect(xml).to include("<?xml")
        expect(xml).to include("Types")
        expect(xml).to include("wordprocessingml")
      end
    end

    describe "#document_xml" do
      it "generates document XML with content" do
        xml = service.send(:document_xml, "テスト内容")
        expect(xml).to include("<?xml")
        expect(xml).to include("職務経歴書（改善版）")
        expect(xml).to include("テスト内容")
      end

      it "handles headings with ■ marker" do
        xml = service.send(:document_xml, "■見出し")
        expect(xml).to include("Heading1")
      end
    end
  end
end
