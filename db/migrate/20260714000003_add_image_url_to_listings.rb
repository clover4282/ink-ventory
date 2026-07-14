class AddImageUrlToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :image_url, :string
  end
end
