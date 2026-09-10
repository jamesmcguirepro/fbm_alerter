class CreateAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :alerts do |t|
      t.integer  :listing_id
      t.datetime :sent_at

      t.foreign_key :listings, column: :listing_id, primary_key: :id
    end
  end
end
