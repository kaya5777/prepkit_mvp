class CreateHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :histories do |t|
      t.text :content
      t.datetime :asked_at
      t.text :memo

      t.timestamps
    end
  end
end
