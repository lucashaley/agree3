class AddParentIdToStatements < ActiveRecord::Migration[8.1]
  def change
    add_column :statements, :parent_id, :integer, null: true
  end
end
