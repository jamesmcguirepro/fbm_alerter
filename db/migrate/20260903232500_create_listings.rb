class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.string :title, null: false
      t.float    :price
      t.string   :location
      t.string   :url
      t.string   :image_url
      t.string   :search_query
      t.datetime :first_seen_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :last_seen_at,  default: -> { 'CURRENT_TIMESTAMP' }
      t.boolean  :is_sold,       default: false
    end
  end
end