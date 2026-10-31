# frozen_string_literal: true

# Base class for listing filters. Each filter is responsible for one concern
# (title relevance, distance, sold status, etc.) and can be composed in any
# order inside the SearchService pipeline.
class ListingFilter
  # Called once before processing any listings (setup phase).
  # Override to initialize per-search state.
  def before_search(_search_object)
  end

  # Called for each listing after it passes prior filters.
  # Return `true` to keep the listing, `false` to discard it.
  def filter(_listing, _search_object)
    raise NotImplementedError, "#{self.class}#filter must be implemented"
  end

  # Called after processing all listings (teardown phase).
  # Override to report stats or clean up.
  # @param stats [Hash] mutable stats hash carried through the pipeline
  def after_search(_stats = {})
  end
end
