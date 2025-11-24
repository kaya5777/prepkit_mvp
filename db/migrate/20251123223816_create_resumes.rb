class CreateResumes < ActiveRecord::Migration[7.2]
  def change
    create_table :resumes do |t|
      t.references :user, null: false, foreign_key: true
      t.text :raw_text
      t.text :summary
      t.string :status, null: false, default: 'draft'
      t.datetime :analyzed_at

      t.timestamps
    end

    add_index :resumes, :status
    add_index :resumes, [:user_id, :created_at]
  end
end
