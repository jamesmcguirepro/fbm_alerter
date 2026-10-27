class RenameRadiusKmToRadiusMi < ActiveRecord::Migration[8.1]
  # The app is US-focused, so miles are the unit users think in. Facebook's
  # search URL also takes radius in miles; only the SociaVault API wants km, so
  # keeping miles here leaves exactly one conversion at the API boundary.
  KM_PER_MILE = 1.609344
  DEFAULT_RADIUS_MI = 40
  MAX_RADIUS_MI = 500

  def up
    rename_column :saved_searches, :radius_km, :radius_mi

    # Convert the existing kilometre values once. Overseas users will see a
    # slight rounding difference, but the alternative is keeping a unit the
    # forms, list and Facebook link do not use.
    execute <<~SQL
      UPDATE saved_searches
      SET radius_mi = CASE
        WHEN radius_mi IS NULL THEN #{DEFAULT_RADIUS_MI}
        ELSE MAX(1, MIN(#{MAX_RADIUS_MI}, CAST(ROUND(radius_mi / #{KM_PER_MILE}) AS INTEGER)))
      END
    SQL
  end

  def down
    execute <<~SQL
      UPDATE saved_searches
      SET radius_mi = CAST(ROUND(radius_mi * #{KM_PER_MILE}) AS INTEGER)
    SQL

    rename_column :saved_searches, :radius_mi, :radius_km
  end
end
