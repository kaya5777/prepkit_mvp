require 'rails_helper'

RSpec.describe HistoryPresenter do
  let(:user) { create(:user) }

  describe "with single-stage JSON content" do
    let(:history) do
      create(:history,
        user: user,
        company_name: "テスト株式会社",
        asked_at: Time.zone.parse("2025-01-15 23:30:00 +0900"), # JST time
        content: single_stage_json_content,
        memo: "テストメモ"
      )
    end
    let(:single_stage_json_content) do
      <<~JSON
        ```json
        {
          "questions": [
            {"question": "質問1", "intent": "意図1", "answer_points": ["ポイント1"], "level": "Junior"},
            {"question": "質問2", "intent": "意図2", "answer_points": ["ポイント2"], "level": "Mid"}
          ],
          "star_answers": [
            {"question": "STAR質問", "situation": "状況", "task": "課題", "action": "行動", "result": "結果"}
          ],
          "reverse_questions": "逆質問アドバイス",
          "tech_checklist": ["チェック項目1", "チェック項目2"]
        }
        ```
      JSON
    end
    let(:presenter) { described_class.new(history) }

    describe "#display_company_name" do
      it "returns company name when present" do
        expect(presenter.display_company_name).to eq("テスト株式会社")
      end

      it "returns default when company name is nil" do
        history.update(company_name: nil)
        expect(presenter.display_company_name).to eq("（会社名未登録）")
      end

      it "returns default when company name is blank" do
        history.update(company_name: "")
        expect(presenter.display_company_name).to eq("（会社名未登録）")
      end
    end

    describe "#formatted_asked_at" do
      it "returns formatted datetime in JST" do
        expect(presenter.formatted_asked_at).to eq("2025年01月15日 23:30")
      end

      it "returns nil when asked_at is nil" do
        history.update(asked_at: nil)
        expect(presenter.formatted_asked_at).to be_nil
      end
    end

    describe "#valid_json?" do
      it "returns true for valid JSON" do
        expect(presenter.valid_json?).to be true
      end

      it "returns false for invalid JSON" do
        history.update(content: "invalid json")
        expect(presenter.valid_json?).to be false
      end
    end

    describe "#multi_stage?" do
      it "returns false for single-stage data" do
        expect(presenter.multi_stage?).to be false
      end
    end

    describe "#questions" do
      it "returns questions array" do
        questions = presenter.questions
        expect(questions).to be_an(Array)
        expect(questions.size).to eq(2)
        expect(questions.first[:question]).to eq("質問1")
      end

      it "returns empty array for invalid JSON" do
        history.update(content: "invalid")
        expect(presenter.questions).to eq([])
      end
    end

    describe "#star_answers" do
      it "returns star_answers array" do
        star_answers = presenter.star_answers
        expect(star_answers).to be_an(Array)
        expect(star_answers.first[:question]).to eq("STAR質問")
      end
    end

    describe "#reverse_questions" do
      it "returns reverse_questions string" do
        expect(presenter.reverse_questions).to eq("逆質問アドバイス")
      end

      it "returns empty string for invalid JSON" do
        history.update(content: "invalid")
        expect(presenter.reverse_questions).to eq("")
      end
    end

    describe "#tech_checklist" do
      it "returns tech_checklist array" do
        checklist = presenter.tech_checklist
        expect(checklist).to eq([ "チェック項目1", "チェック項目2" ])
      end
    end

    describe "#has_questions?" do
      it "returns true when questions exist" do
        expect(presenter.has_questions?).to be true
      end
    end

    describe "#has_star_answers?" do
      it "returns true when star_answers exist" do
        expect(presenter.has_star_answers?).to be true
      end
    end

    describe "#has_reverse_questions?" do
      it "returns true when reverse_questions exist as string" do
        expect(presenter.has_reverse_questions?).to be true
      end

      it "returns false when reverse_questions is empty string" do
        history.update(content: '```json\n{"reverse_questions": ""}\n```')
        expect(presenter.has_reverse_questions?).to be false
      end
    end

    describe "#has_tech_checklist?" do
      it "returns true when tech_checklist exists" do
        expect(presenter.has_tech_checklist?).to be true
      end
    end
  end

  describe "with multi-stage JSON content" do
    let(:history) do
      create(:history,
        user: user,
        company_name: "マルチステージ株式会社",
        content: multi_stage_json_content,
        stage_1_memo: "1次面接メモ",
        stage_2_memo: "2次面接メモ",
        stage_3_memo: "3次面接メモ"
      )
    end
    let(:multi_stage_json_content) do
      <<~JSON
        ```json
        {
          "stage_1": {
            "questions": [{"question": "1次質問", "intent": "意図", "answer_points": ["ポイント"], "level": "Junior"}],
            "star_answers": [{"question": "1次STAR"}],
            "reverse_questions": "1次逆質問",
            "tech_checklist": ["1次チェック"]
          },
          "stage_2": {
            "questions": [{"question": "2次質問"}],
            "star_answers": [],
            "reverse_questions": "2次逆質問",
            "tech_checklist": ["2次チェック"]
          },
          "stage_3": {
            "questions": [{"question": "3次質問"}],
            "star_answers": [],
            "reverse_questions": "3次逆質問",
            "tech_checklist": []
          }
        }
        ```
      JSON
    end
    let(:presenter) { described_class.new(history) }

    describe "#multi_stage?" do
      it "returns true for multi-stage data" do
        expect(presenter.multi_stage?).to be true
      end
    end

    describe "#stage_data" do
      it "returns stage_1 data" do
        data = presenter.stage_data(1)
        questions = data[:questions] || data["questions"]
        expect(questions).to be_an(Array)
      end

      it "returns empty hash for non-existent stage" do
        data = presenter.stage_data(99)
        expect(data).to eq({})
      end
    end

    describe "#questions with stage parameter" do
      it "returns stage_1 questions" do
        questions = presenter.questions(1)
        expect(questions.first[:question] || questions.first["question"]).to eq("1次質問")
      end

      it "returns stage_2 questions" do
        questions = presenter.questions(2)
        expect(questions.first[:question] || questions.first["question"]).to eq("2次質問")
      end

      it "returns empty array when stage is nil" do
        questions = presenter.questions(nil)
        expect(questions).to eq([])
      end
    end

    describe "#star_answers with stage parameter" do
      it "returns stage_1 star_answers" do
        star_answers = presenter.star_answers(1)
        expect(star_answers.first[:question] || star_answers.first["question"]).to eq("1次STAR")
      end

      it "returns empty array when stage has no star_answers" do
        star_answers = presenter.star_answers(2)
        expect(star_answers).to eq([])
      end
    end

    describe "#reverse_questions with stage parameter" do
      it "returns stage_1 reverse_questions" do
        expect(presenter.reverse_questions(1)).to eq("1次逆質問")
      end

      it "returns stage_2 reverse_questions" do
        expect(presenter.reverse_questions(2)).to eq("2次逆質問")
      end

      it "returns empty string when stage is nil" do
        expect(presenter.reverse_questions(nil)).to eq("")
      end
    end

    describe "#tech_checklist with stage parameter" do
      it "returns stage_1 tech_checklist" do
        expect(presenter.tech_checklist(1)).to eq([ "1次チェック" ])
      end

      it "returns empty array when stage has no checklist" do
        expect(presenter.tech_checklist(3)).to eq([])
      end
    end

    describe "#has_questions? with stage parameter" do
      it "returns true when stage has questions" do
        expect(presenter.has_questions?(1)).to be true
      end
    end

    describe "#has_star_answers? with stage parameter" do
      it "returns true when stage has star_answers" do
        expect(presenter.has_star_answers?(1)).to be true
      end

      it "returns false when stage has no star_answers" do
        expect(presenter.has_star_answers?(2)).to be false
      end
    end

    describe "#has_reverse_questions? with stage parameter" do
      it "returns true when stage has reverse_questions" do
        expect(presenter.has_reverse_questions?(1)).to be true
      end
    end

    describe "#has_tech_checklist? with stage parameter" do
      it "returns true when stage has tech_checklist" do
        expect(presenter.has_tech_checklist?(1)).to be true
      end

      it "returns false when stage has empty checklist" do
        expect(presenter.has_tech_checklist?(3)).to be false
      end
    end

    describe "#has_any_stage_data?" do
      it "returns true when any stage has data" do
        expect(presenter.has_any_stage_data?).to be true
      end

      it "returns true for single-stage data" do
        single_stage_history = create(:history, content: '```json\n{"questions": []}\n```')
        single_stage_presenter = described_class.new(single_stage_history)
        expect(single_stage_presenter.has_any_stage_data?).to be true
      end
    end

    describe "#stage_memo" do
      it "returns stage_1_memo" do
        expect(presenter.stage_memo(1)).to eq("1次面接メモ")
      end

      it "returns stage_2_memo" do
        expect(presenter.stage_memo(2)).to eq("2次面接メモ")
      end

      it "returns stage_3_memo" do
        expect(presenter.stage_memo(3)).to eq("3次面接メモ")
      end

      it "returns nil for invalid stage" do
        expect(presenter.stage_memo(99)).to be_nil
      end
    end

    describe "#has_stage_memo?" do
      it "returns true when stage has memo" do
        expect(presenter.has_stage_memo?(1)).to be true
      end

      it "returns false when stage has no memo" do
        history.update(stage_1_memo: nil)
        expect(presenter.has_stage_memo?(1)).to be false
      end
    end
  end
end
