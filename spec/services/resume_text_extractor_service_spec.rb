require 'rails_helper'

RSpec.describe ResumeTextExtractorService do
  let(:user) { create(:user) }
  let(:resume) { create(:resume, user: user) }

  describe "#call" do
    context "when no file is attached" do
      it "returns nil" do
        result = described_class.new(resume).call
        expect(result).to be_nil
      end
    end
  end

  describe "private methods" do
    let(:service) { described_class.new(resume) }

    describe "#clean_text" do
      it "normalizes whitespace" do
        text = "Line1\r\nLine2\t\tLine3   Line4\n\n\n\nLine5"
        result = service.send(:clean_text, text)

        expect(result).not_to include("\r\n")
        expect(result).not_to include("\t\t")
        expect(result).not_to include("   ")
      end

      it "returns empty string for nil" do
        result = service.send(:clean_text, nil)
        expect(result).to eq("")
      end

      it "strips leading and trailing whitespace" do
        text = "  content  "
        result = service.send(:clean_text, text)
        expect(result).to eq("content")
      end

      it "reduces multiple newlines to two" do
        text = "Line1\n\n\n\nLine2"
        result = service.send(:clean_text, text)
        expect(result).to eq("Line1\n\nLine2")
      end
    end
  end
end
