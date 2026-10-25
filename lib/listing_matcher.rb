# frozen_string_literal: true

# Decides whether a listing title is relevant to a search query.
#
# Matching is deliberately loose: any single keyword from the query (or one of
# its nicknames) appearing in the title is enough. Facebook's relevance order
# puts real matches first, and SearchService stops paging as soon as a page has
# no matches, so the loose match is what keeps recall high without spending
# extra credits.
class ListingMatcher
  # Nickname -> canonical make. Both the query and the listing title are
  # normalized through this map, so "husky" matches "Husqvarna" and vice versa.
  # Kept small on purpose: every alias widens the match net, and aliases are
  # cheap to add here once a real search shows the need.
  KEYWORD_ALIASES = {
    'husky' => 'husqvarna',
    'chevy' => 'chevrolet',
    'vw' => 'volkswagen'
  }.freeze

  # @param query [String] the saved search query
  def initialize(query:)
    @keywords = normalize(text: query).split.uniq
  end

  # @param title [String, nil]
  # @return [Boolean] true when the title contains any query keyword
  def title_match?(title:)
    return false if @keywords.empty?

    normalized_title = normalize(text: title)
    @keywords.any? { |keyword| normalized_title.include?(keyword) }
  end

  # @param title [String, nil]
  # @return [Boolean] true when the title contains ALL query keywords
  def exact_match?(title:)
    return false if @keywords.empty?

    normalized_title = normalize(text: title)
    @keywords.all? { |keyword| normalized_title.include?(keyword) }
  end

  private

  # Downcase and replace nickname words with their canonical make. Splitting on
  # non-alphanumerics keeps punctuation ("Husqvarna-Berg", "chevy's") from
  # hiding a match.
  def normalize(text:)
    text.to_s.downcase.gsub(/[a-z0-9]+/) { |word| KEYWORD_ALIASES.fetch(word, word) }
  end
end
