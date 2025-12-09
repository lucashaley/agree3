class AddAuthorToStatements < ActiveRecord::Migration[8.1]
  def change
    add_reference :statements, :author, null: false, foreign_key: { to_table: :users }
  end
end
