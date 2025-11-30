require 'rails_helper'

RSpec.describe "histories/index.html.erb", type: :view do
  # index.html.erb does not exist, using my_histories.html.erb and all_histories.html.erb instead
  it "template does not exist - using my_histories and all_histories instead" do
    expect(File.exist?(Rails.root.join("app", "views", "histories", "index.html.erb"))).to be false
  end
end
