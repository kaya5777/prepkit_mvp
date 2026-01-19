class AddProviderToResumeAnalyses < ActiveRecord::Migration[7.2]
  def change
    add_column :resume_analyses, :provider, :string
    add_index :resume_analyses, [ :resume_id, :category, :provider ], name: "index_resume_analyses_on_resume_category_provider"
  end
end
