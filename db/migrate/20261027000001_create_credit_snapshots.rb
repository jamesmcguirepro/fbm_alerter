class CreateCreditSnapshots < ActiveRecord::Migration[8.1]
  def up
    create_table :credit_snapshots, if_not_exists: true do |t|
      # Balance recorded at a point in time.
      t.decimal :balance, precision: 12, scale: 2, null: false
      t.references :monitor_run, null: true, index: true

      t.timestamps
    end
  end

  def down
    drop_table :credit_snapshots, if_exists: true
  end
end
