class AddJobDescriptionToHistories < ActiveRecord::Migration[7.1]
  def change
    add_column :histories, :job_description, :text
    add_column :histories, :company_name, :string
  end
end
