FactoryBot.define do
  factory :question_answer do
    history { nil }
    question_index { 1 }
    question_text { "MyText" }
    user_answer { "MyText" }
    score { 1 }
    feedback { "" }
    status { "MyString" }
  end
end
