require 'rails_helper'

RSpec.describe HistoriesHelper, type: :helper do
  let(:user) { create(:user, name: "Test User", email: "test@example.com") }
  let(:history) { create(:history, user: user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe "#can_edit_history?" do
    it "returns true when current user is the owner" do
      expect(helper.can_edit_history?(history)).to be true
    end

    it "returns false when current user is not the owner" do
      other_user = create(:user)
      other_history = create(:history, user: other_user)
      expect(helper.can_edit_history?(other_history)).to be false
    end
  end

  describe "#user_display_name" do
    it "returns user name when name is present" do
      expect(helper.user_display_name(user)).to eq("Test User")
    end

    it "returns email prefix when name is nil" do
      user_without_name = create(:user, name: nil, email: "john@example.com")
      expect(helper.user_display_name(user_without_name)).to eq("john")
    end
  end

  describe "#user_avatar_initial" do
    it "returns first letter of name when name is present" do
      expect(helper.user_avatar_initial(user)).to eq("T")
    end

    it "returns first letter of email when name is nil" do
      user_without_name = create(:user, name: nil, email: "alice@example.com")
      expect(helper.user_avatar_initial(user_without_name)).to eq("A")
    end
  end

  describe "#user_avatar" do
    it "renders image tag when avatar_url is present" do
      allow(user).to receive(:avatar_url).and_return("https://example.com/avatar.jpg")
      result = helper.user_avatar(user)
      expect(result).to include("img")
      expect(result).to include("avatar.jpg")
    end

    it "renders div with initial when avatar_url is blank" do
      allow(user).to receive(:avatar_url).and_return(nil)
      result = helper.user_avatar(user)
      expect(result).to include("T")
      expect(result).to include("bg-primary-100")
    end

    it "accepts custom size parameter" do
      allow(user).to receive(:avatar_url).and_return(nil)
      result = helper.user_avatar(user, size: "w-10 h-10")
      expect(result).to include("w-10 h-10")
    end
  end

  describe "#user_avatar_with_name" do
    it "renders avatar and name together" do
      allow(user).to receive(:avatar_url).and_return(nil)
      result = helper.user_avatar_with_name(user)
      expect(result).to include("Test User")
      expect(result).to include("flex items-center gap-2")
    end
  end

  describe "#icon_svg" do
    it "renders svg with given path" do
      result = helper.icon_svg("M5 10h14")
      expect(result).to include("svg")
      expect(result).to include("M5 10h14")
    end

    it "accepts custom css class" do
      result = helper.icon_svg("M5 10h14", css_class: "w-10 h-10")
      expect(result).to include("w-10 h-10")
    end
  end

  describe "#check_icon" do
    it "renders check icon svg" do
      result = helper.check_icon
      expect(result).to include("svg")
      expect(result).to include("M9 12l2 2 4-4")
    end
  end

  describe "#question_icon" do
    it "renders question icon svg" do
      result = helper.question_icon
      expect(result).to include("svg")
      expect(result).to include("M8.228 9c")
    end
  end

  describe "#star_icon" do
    it "renders star icon svg" do
      result = helper.star_icon
      expect(result).to include("svg")
      expect(result).to include("M11.049 2.927c")
    end
  end

  describe "#edit_icon" do
    it "renders edit icon svg" do
      result = helper.edit_icon
      expect(result).to include("svg")
      expect(result).to include("M11 5H6a2 2 0 00-2 2v11")
    end
  end

  describe "#delete_icon" do
    it "renders delete icon svg" do
      result = helper.delete_icon
      expect(result).to include("svg")
      expect(result).to include("M19 7l-.867 12.142")
    end
  end

  describe "#warning_icon" do
    it "renders warning icon svg" do
      result = helper.warning_icon
      expect(result).to include("svg")
      expect(result).to include("M12 9v2m0 4h.01")
    end
  end

  describe "#arrow_icon_filled" do
    it "renders filled arrow icon svg" do
      result = helper.arrow_icon_filled
      expect(result).to include("svg")
      expect(result).to include("M7.293 14.707a1 1 0 010-1.414")
    end
  end

  describe "#section_header" do
    it "renders section header with title" do
      result = helper.section_header("Test Title", "bg-blue-100")
      expect(result).to include("Test Title")
      expect(result).to include("bg-blue-100")
    end

    it "renders section header with icon" do
      icon = helper.check_icon
      result = helper.section_header("Test Title", "bg-blue-100", icon: icon)
      expect(result).to include("Test Title")
      expect(result).to include("svg")
    end
  end

  describe "#numbered_badge" do
    it "renders numbered badge with default color" do
      result = helper.numbered_badge(1)
      expect(result).to include("1")
      expect(result).to include("bg-indigo-600")
    end

    it "renders numbered badge with custom color" do
      result = helper.numbered_badge(2, color_class: "bg-red-600")
      expect(result).to include("2")
      expect(result).to include("bg-red-600")
    end
  end

  describe "#star_label" do
    it "renders STAR label with letter and color" do
      result = helper.star_label("S", "text-blue-600")
      expect(result).to include("S:")
      expect(result).to include("text-blue-600")
    end
  end
end
