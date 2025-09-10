class PreparationsController < ApplicationController
  def new
  end

  def create
    Rails.logger.debug params.inspect
    jd = params[:job_description]
  
    client = OpenAI::Client.new
    response = client.chat.completions.create(
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: "あなたは面接官です。JSON形式で出力してください。" },
        { role: "user", content: prompt_for(jd) }
      ]
    )

    # json_string = response.output_text
    json_string = response.choices[0].message.content
    json_string = json_string.gsub(/\A```json|```|\A```|\Z```/m, '').strip
    @result = JSON.parse(json_string, symbolize_names: true)
  
    render :show
  end
  
  private

  def prompt_for(jd)
    <<~PROMPT
    以下の求人票をもとに面接準備キットを生成してください。
    JSON形式で出力してください。

    出力フォーマット:
    {
      "questions": ["質問1", "質問2", ...],
      "star_answers": [
        {"question": "質問1", "situation": "...", "task": "...", "action": "...", "result": "..."}
      ],
      "reverse_questions": ["逆質問1", "逆質問2"],
      "tech_checklist": ["チェック項目1", "チェック項目2"]
    }

    求人票:
    #{jd}
    PROMPT
  end
end
