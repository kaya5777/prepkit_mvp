class CreateResumeAnalyses < ActiveRecord::Migration[7.2]
  def change
    create_table :resume_analyses do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :category, null: false  # structure/content/expression/layout
      t.integer :score               # 0-100
      t.json :feedback, default: {} # {issues: [], suggestions: [], good_points: []}
      t.text :improved_text          # 改善版テキスト（カテゴリ別）

      t.timestamps
    end

    add_index :resume_analyses, :category
    add_index :resume_analyses, [:resume_id, :category], unique: true
  end
end
