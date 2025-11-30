require 'rails_helper'

RSpec.describe QuestionAnswer, type: :model do
  describe "associations" do
    it { should belong_to(:history) }
    it { should belong_to(:user).optional }
  end

  describe "validations" do
    it { should validate_presence_of(:question_index) }
    it { should validate_numericality_of(:question_index).only_integer.is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:question_text) }
    it { should validate_presence_of(:user_answer) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[draft scored]) }
    it { should validate_numericality_of(:score).only_integer.is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100).allow_nil }
  end

  describe "scopes" do
    let(:history) { create(:history) }
    let!(:scored_answer) { create(:question_answer, :scored, history: history, question_index: 1) }
    let!(:draft_answer) { create(:question_answer, history: history, question_index: 2, status: "draft") }
    let!(:other_user_answer) { create(:question_answer, :scored, history: history, question_index: 3) }

    describe ".scored" do
      it "returns only scored answers" do
        expect(QuestionAnswer.scored).to include(scored_answer, other_user_answer)
        expect(QuestionAnswer.scored).not_to include(draft_answer)
      end
    end

    describe ".drafts" do
      it "returns only draft answers" do
        expect(QuestionAnswer.drafts).to include(draft_answer)
        expect(QuestionAnswer.drafts).not_to include(scored_answer, other_user_answer)
      end
    end

    describe ".for_question" do
      it "returns answers for specific question index" do
        expect(QuestionAnswer.for_question(1)).to include(scored_answer)
        expect(QuestionAnswer.for_question(1)).not_to include(draft_answer, other_user_answer)
      end
    end

    describe ".recent_first" do
      it "orders by created_at descending" do
        results = QuestionAnswer.recent_first
        expect(results.first.created_at).to be >= results.last.created_at
      end
    end

    describe ".by_user" do
      let(:user) { create(:user) }
      let!(:user_answer) { create(:question_answer, :scored, history: history, user: user) }

      it "returns answers for specific user" do
        expect(QuestionAnswer.by_user(user)).to include(user_answer)
        expect(QuestionAnswer.by_user(user)).not_to include(scored_answer)
      end
    end
  end

  describe "instance methods" do
    describe "#scored?" do
      it "returns true when status is scored" do
        answer = build(:question_answer, :scored)
        expect(answer.scored?).to be true
      end

      it "returns false when status is draft" do
        answer = build(:question_answer, status: "draft")
        expect(answer.scored?).to be false
      end
    end

    describe "#draft?" do
      it "returns true when status is draft" do
        answer = build(:question_answer, status: "draft")
        expect(answer.draft?).to be true
      end

      it "returns false when status is scored" do
        answer = build(:question_answer, :scored)
        expect(answer.draft?).to be false
      end
    end

    describe "#good_points" do
      it "returns good_points from feedback" do
        answer = build(:question_answer, :scored)
        expect(answer.good_points).to eq(["具体的な説明ができている"])
      end

      it "returns empty array when feedback is nil" do
        answer = build(:question_answer, feedback: nil)
        expect(answer.good_points).to eq([])
      end

      it "returns empty array when good_points key is missing" do
        answer = build(:question_answer, feedback: {})
        expect(answer.good_points).to eq([])
      end
    end

    describe "#improvements" do
      it "returns improvements from feedback" do
        answer = build(:question_answer, :scored)
        expect(answer.improvements).to eq(["数値で示すとより良い"])
      end

      it "returns empty array when feedback is nil" do
        answer = build(:question_answer, feedback: nil)
        expect(answer.improvements).to eq([])
      end
    end

    describe "#improvement_example" do
      it "returns improvement_example from feedback" do
        answer = build(:question_answer, :scored)
        expect(answer.improvement_example).to include("5人のチームで開発し")
      end

      it "returns empty string when feedback is nil" do
        answer = build(:question_answer, feedback: nil)
        expect(answer.improvement_example).to eq("")
      end
    end

    describe "#score_gradient_class" do
      it "returns gray gradient when score is nil" do
        answer = build(:question_answer, score: nil)
        expect(answer.score_gradient_class).to eq("bg-gradient-to-br from-gray-400 to-gray-600")
      end

      it "returns green gradient when score >= 80" do
        answer = build(:question_answer, score: 85)
        expect(answer.score_gradient_class).to eq("bg-gradient-to-br from-green-400 to-green-600")
      end

      it "returns blue gradient when score >= 60 and < 80" do
        answer = build(:question_answer, score: 70)
        expect(answer.score_gradient_class).to eq("bg-gradient-to-br from-blue-400 to-blue-600")
      end

      it "returns amber gradient when score < 60" do
        answer = build(:question_answer, score: 50)
        expect(answer.score_gradient_class).to eq("bg-gradient-to-br from-amber-400 to-amber-600")
      end
    end

    describe "#score_badge_class" do
      it "returns gray badge when score is nil" do
        answer = build(:question_answer, score: nil)
        expect(answer.score_badge_class).to eq("bg-gray-100 text-gray-800")
      end

      it "returns green badge when score >= 80" do
        answer = build(:question_answer, score: 90)
        expect(answer.score_badge_class).to eq("bg-green-100 text-green-800")
      end

      it "returns blue badge when score >= 60 and < 80" do
        answer = build(:question_answer, score: 65)
        expect(answer.score_badge_class).to eq("bg-blue-100 text-blue-800")
      end

      it "returns amber badge when score < 60" do
        answer = build(:question_answer, score: 45)
        expect(answer.score_badge_class).to eq("bg-amber-100 text-amber-800")
      end
    end

    describe "#display_score" do
      it "returns score when present" do
        answer = build(:question_answer, score: 75)
        expect(answer.display_score).to eq(75)
      end

      it "returns 0 when score is nil" do
        answer = build(:question_answer, score: nil)
        expect(answer.display_score).to eq(0)
      end
    end
  end
end
