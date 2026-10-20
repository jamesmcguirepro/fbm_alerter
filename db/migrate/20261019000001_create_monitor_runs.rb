class CreateMonitorRuns < ActiveRecord::Migration[8.1]
  def up
    create_table :monitor_runs, if_not_exists: true do |t|
      # One row per full pass over all saved searches — scheduled, GUI-triggered
      # or CLI-triggered. Single-search runs are tracked separately in
      # search_runs and deliberately do not count here.
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string :initiated_by, null: false

      t.timestamps
    end

    add_index :monitor_runs, :started_at, if_not_exists: true
  end

  def down
    drop_table :monitor_runs, if_exists: true
  end
end
