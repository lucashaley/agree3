class CreateStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :statements do |t|
      t.text :content
      t.timestamps
    end
  end
end
