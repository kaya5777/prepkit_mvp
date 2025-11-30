require 'rails_helper'

RSpec.describe "histories/create.html.erb", type: :view do
  it "renders placeholder content" do
    render
    expect(rendered).to include("Histories#create")
  end
end
