class RemoveUniqueIndexFromResumeAnalyses < ActiveRecord::Migration[7.2]
  def change
    # 既存のユニーク制約を削除
    remove_index :resume_analyses, name: "index_resume_analyses_on_resume_id_and_category", if_exists: true

    # providerを含まない通常のインデックスを追加（必要に応じて）
    add_index :resume_analyses, [:resume_id, :category], if_not_exists: true
  end
end
