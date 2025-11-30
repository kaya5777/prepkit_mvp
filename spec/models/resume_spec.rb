require "rails_helper"

RSpec.describe Resume, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:resume_analyses).dependent(:destroy) }
    it { should have_one_attached(:original_file) }
  end

  describe "validations" do
    it { should validate_inclusion_of(:status).in_array(%w[draft analyzing analyzed error]) }
  end

  describe "scopes" do
    let!(:user) { create(:user) }
    let!(:draft_resume) { create(:resume, user: user, status: "draft") }
    let!(:analyzed_resume) { create(:resume, :analyzed, user: user) }
    let!(:error_resume) { create(:resume, :error, user: user) }

    it "returns analyzed resumes only" do
      expect(Resume.analyzed).to include(analyzed_resume)
      expect(Resume.analyzed).not_to include(draft_resume, error_resume)
    end
  end

  describe "#overall_score" do
    context "when resume has analyses" do
      let(:resume) { create(:resume, :analyzed) }

      before do
        resume.resume_analyses.each_with_index do |analysis, index|
          analysis.update(score: (index + 1) * 20) # 20, 40, 60, 80
        end
      end

      it "returns the average score" do
        expect(resume.overall_score).to eq(50) # (20 + 40 + 60 + 80) / 4
      end
    end

    context "when resume has no analyses" do
      let(:resume) { create(:resume) }

      it "returns nil" do
        expect(resume.overall_score).to be_nil
      end
    end
  end

  describe "#all_good_points" do
    let(:resume) { create(:resume, :analyzed) }

    it "collects all good points from analyses" do
      expect(resume.all_good_points).to be_an(Array)
      expect(resume.all_good_points).not_to be_empty
    end
  end

  describe "status transitions" do
    let(:resume) { create(:resume, :with_file) }

    it "can transition from draft to analyzing" do
      expect { resume.update!(status: "analyzing") }.not_to raise_error
    end

    it "can transition from analyzing to analyzed" do
      resume.update!(status: "analyzing")
      expect { resume.update!(status: "analyzed", analyzed_at: Time.current) }.not_to raise_error
    end

    it "can transition to error from any state" do
      expect { resume.update!(status: "error") }.not_to raise_error
    end
  end
end
