require "rails_helper"

RSpec.describe History, type: :model do
  describe "associations" do
    it { should belong_to(:user).optional }
    it { should have_many(:question_answers).dependent(:destroy) }
  end

  describe "#rank_info" do
    it "returns S rank info for score 90-100" do
      history = build(:history, :with_match_analysis, match_score: 95, match_rank: "S")
      rank_info = history.rank_info
      expect(rank_info[:label]).to eq("非常に高い")
      expect(rank_info[:range]).to eq(90..100)
    end

    it "returns A rank info for score 80-89" do
      history = build(:history, :with_match_analysis, match_score: 85, match_rank: "A")
      rank_info = history.rank_info
      expect(rank_info[:label]).to eq("高い")
      expect(rank_info[:range]).to eq(80..89)
    end

    it "returns B rank info for score 70-79" do
      history = build(:history, :with_match_analysis, match_score: 75, match_rank: "B")
      rank_info = history.rank_info
      expect(rank_info[:label]).to eq("やや高い")
      expect(rank_info[:range]).to eq(70..79)
    end

    it "returns C rank info for score below 70" do
      history = build(:history, :with_match_analysis, match_score: 65, match_rank: "C")
      rank_info = history.rank_info
      expect(rank_info[:label]).to eq("普通")
      expect(rank_info[:range]).to eq(60..69)
    end

    it "returns default info when no rank" do
      history = build(:history)
      rank_info = history.rank_info
      expect(rank_info[:label]).to eq("要改善")
      expect(rank_info[:range]).to eq(0..59)
    end
  end
end
