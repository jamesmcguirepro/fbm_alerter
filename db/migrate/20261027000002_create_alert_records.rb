class CreateAlertRecords < ActiveRecord::Migration[8.1]
  def up
    create_table :alert_records, if_not_exists: true do |t|
      t.date :date, null: false
      t.string :type, null: false

      t.timestamps
    end

    add_index :alert_records, [:date, :type], unique: true, if_not_exists: true
  end

  def down
    drop_table :alert_records, if_exists: true
  end
end
