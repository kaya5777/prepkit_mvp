require "rails_helper"

RSpec.describe ResumeAnalysis, type: :model do
  describe "associations" do
    it { should belong_to(:resume) }
  end

  describe "validations" do
    it { should validate_presence_of(:category) }
    it { should validate_inclusion_of(:category).in_array(%w[structure content expression layout]) }

    it "validates score is between 0 and 100" do
      analysis = build(:resume_analysis, score: 150)
      expect(analysis).not_to be_valid
      expect(analysis.errors[:score]).to be_present
    end

    it "allows nil score" do
      analysis = build(:resume_analysis, score: nil)
      expect(analysis).to be_valid
    end
  end

  describe "#category_name" do
    it "returns Japanese name for structure" do
      analysis = build(:resume_analysis, :structure)
      expect(analysis.category_name).to eq("構成")
    end

    it "returns Japanese name for content" do
      analysis = build(:resume_analysis, :content)
      expect(analysis.category_name).to eq("内容")
    end

    it "returns Japanese name for expression" do
      analysis = build(:resume_analysis, :expression)
      expect(analysis.category_name).to eq("表現")
    end

    it "returns Japanese name for layout" do
      analysis = build(:resume_analysis, :layout)
      expect(analysis.category_name).to eq("見やすさ")
    end
  end

  describe "#grade" do
    it "returns S for score 90-100" do
      analysis = build(:resume_analysis, score: 95)
      expect(analysis.grade).to eq("S")
    end

    it "returns A for score 80-89" do
      analysis = build(:resume_analysis, score: 85)
      expect(analysis.grade).to eq("A")
    end

    it "returns B for score 70-79" do
      analysis = build(:resume_analysis, score: 75)
      expect(analysis.grade).to eq("B")
    end

    it "returns C for score 60-69" do
      analysis = build(:resume_analysis, score: 65)
      expect(analysis.grade).to eq("C")
    end

    it "returns D for score below 60" do
      analysis = build(:resume_analysis, score: 50)
      expect(analysis.grade).to eq("D")
    end

    it "returns nil for nil score" do
      analysis = build(:resume_analysis, score: nil)
      expect(analysis.grade).to be_nil
    end
  end

  describe "feedback accessors" do
    let(:analysis) { create(:resume_analysis) }

    it "returns good_points array" do
      expect(analysis.good_points).to be_an(Array)
      expect(analysis.good_points).not_to be_empty
    end

    it "returns issues array" do
      expect(analysis.issues).to be_an(Array)
    end

    it "returns suggestions array" do
      expect(analysis.suggestions).to be_an(Array)
    end

    it "returns examples array" do
      expect(analysis.examples).to be_an(Array)
      expect(analysis.examples.first).to have_key("before")
      expect(analysis.examples.first).to have_key("after")
    end

    it "returns empty arrays when feedback is empty" do
      analysis = create(:resume_analysis, feedback: {})
      expect(analysis.good_points).to eq([])
      expect(analysis.issues).to eq([])
      expect(analysis.suggestions).to eq([])
      expect(analysis.examples).to eq([])
    end
  end
end
