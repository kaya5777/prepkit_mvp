require 'rails_helper'

RSpec.describe "histories/update.html.erb", type: :view do
  it "renders placeholder content" do
    render
    expect(rendered).to include("Histories#update")
  end
end
