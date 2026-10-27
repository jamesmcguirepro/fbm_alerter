# frozen_string_literal: true

# Distance conversion helpers. Saved searches store miles (the unit the UI and
# Facebook's search URL use); the SociaVault API takes kilometres, so this is
# the one place the conversion lives.
module Distance
  KM_PER_MILE = 1.609344

  def self.miles_to_km(miles)
    return nil if miles.nil?

    miles.to_f * KM_PER_MILE
  end
end
