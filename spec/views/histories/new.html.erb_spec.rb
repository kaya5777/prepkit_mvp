require 'rails_helper'

RSpec.describe "histories/new.html.erb", type: :view do
  let(:history) { History.new }

  before do
    assign(:history, history)
  end

  it "renders new history form" do
    render
    expect(rendered).to include("履歴新規作成")
  end

  it "renders form fields" do
    render
    expect(rendered).to include("会社名")
    expect(rendered).to include("質問内容")
    expect(rendered).to include("メモ")
  end

  it "renders submit button" do
    render
    expect(rendered).to include("登録")
  end
end
