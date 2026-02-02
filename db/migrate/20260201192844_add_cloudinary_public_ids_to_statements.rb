class AddCloudinaryPublicIdsToStatements < ActiveRecord::Migration[8.1]
  def change
    add_column :statements, :square_image_public_id, :string
    add_column :statements, :social_image_public_id, :string

    add_index :statements, :square_image_public_id
    add_index :statements, :social_image_public_id
  end
end
