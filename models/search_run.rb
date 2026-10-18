# frozen_string_literal: true

# == Schema Information
#
# Table name: search_runs
#
#  id              :integer          not null, primary key
#  success         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  saved_search_id :integer          not null
#
# Indexes
#
#  index_search_runs_on_saved_search_id  (saved_search_id)
#
# Foreign Keys
#
#  saved_search_id  (saved_search_id => saved_searches.id)
#
class SearchRun < ActiveRecord::Base
  belongs_to :saved_search
  has_many :listings

  # Record one SociaVault API call (one search credit is spent per call).
  # @param saved_search [SavedSearch] the search that made the call
  # @param success [Boolean] whether the API call returned without error
  def self.record(saved_search:, success: true)
    create!(saved_search_id: saved_search.id, success:)
  end
end
