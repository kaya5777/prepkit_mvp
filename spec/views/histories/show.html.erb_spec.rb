require 'rails_helper'

RSpec.describe "histories/show.html.erb", type: :view do
  let(:history_with_json) do
    History.create!(
      company_name: 'テスト株式会社',
      content: '```json
{
  "questions": ["質問1", "質問2"],
  "star_answers": [
    {
      "question": "STAR質問",
      "situation": "状況",
      "task": "課題",
      "action": "行動",
      "result": "結果"
    }
  ],
  "reverse_questions": ["逆質問1"],
  "tech_checklist": ["技術1"]
}
```',
      asked_at: Time.current,
      memo: 'テストメモ'
    )
  end

  it "renders JSON content correctly" do
    assign(:history, history_with_json)
    assign(:presenter, HistoryPresenter.new(history_with_json))
    render
    expect(rendered).to include('想定質問リスト')
    expect(rendered).to include('質問1')
    expect(rendered).to include('質問2')
    expect(rendered).to include('STAR回答例')
    expect(rendered).to include('逆質問リスト')
    expect(rendered).to include('技術チェックリスト')
  end
end
