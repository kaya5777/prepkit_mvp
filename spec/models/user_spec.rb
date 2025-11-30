require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_many(:resumes).dependent(:destroy) }
    it { should have_many(:histories).dependent(:nullify) }
    it { should have_many(:question_answers).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:user) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe "#latest_analyzed_resume" do
    let(:user) { create(:user) }

    context "when user has analyzed resumes" do
      let!(:old_resume) { create(:resume, :analyzed, user: user, analyzed_at: 2.days.ago) }
      let!(:new_resume) { create(:resume, :analyzed, user: user, analyzed_at: 1.day.ago) }

      it "returns the most recently analyzed resume" do
        expect(user.latest_analyzed_resume).to eq(new_resume)
      end
    end

    context "when user has no analyzed resumes" do
      it "returns nil" do
        expect(user.latest_analyzed_resume).to be_nil
      end
    end
  end
end
