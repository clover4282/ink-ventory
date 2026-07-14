class AddCatalogEngagement < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :clicks_count, :integer, null: false, default: 0
    add_column :listings, :likes_count, :integer, null: false, default: 0

    create_table :listing_likes do |t|
      t.references :listing, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :listing_likes, %i[listing_id user_id], unique: true
  end
end
