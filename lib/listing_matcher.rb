# frozen_string_literal: true

# Decides whether a listing title is relevant to a search query.
#
# Matching is deliberately loose: any single keyword from the query (or one of
# its nicknames) appearing in the title is enough. Facebook's relevance order
# puts real matches first, and SearchService stops paging as soon as a page has
# no matches, so the loose match is what keeps recall high without spending
# extra credits.
#
# Implements the {ListingFilter} interface so it can compose with other
# filters (distance, sold status, etc.) in the search pipeline.
class ListingMatcher < ListingFilter
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

  # @param listing [ListingObject]
  # @param _search_object [SearchObject]
  # @return [Boolean] true when the listing's title contains any query keyword
  def filter(listing, _search_object)
    return false if @keywords.empty? || listing.title.nil?

    title_tokens = split_tokens(listing.title)
    @keywords.any? { |keyword| match_token?(keyword, title_tokens, listing.title) }
  end

  # @param title [String, nil]
  # @return [Boolean] true when the title contains any query keyword
  def title_match?(title:)
    return false if @keywords.empty? || title.nil?

    title_tokens = split_tokens(title)
    @keywords.any? { |keyword| match_token?(keyword, title_tokens, title) }
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

  # Split text into lowercase alphanumeric tokens for word-boundary matching.
  def split_tokens(text)
    text.to_s.downcase.scan(/[a-z0-9]+/)
  end

  # Match a keyword against a listing title using token matching for longer
  # keywords (≥ 3 chars) and digit-alpha boundary matching for shorter ones.
  #
  # Exact token matching prevents "te" from matching "Terrain". For short
  # keywords (< 3 chars), we allow prefix/suffix matches only when separated
  # by a non-letter boundary — this catches model designators like "te300" or
  # "300te" while rejecting pure-letter words like "Terrain".
  def match_token?(keyword, title_tokens, _title_text)
    title_tokens.include?(keyword) ||
      (keyword.length < 3 && title_tokens.any? do |token|
        next false unless token.length > keyword.length

        if token.start_with?(keyword)
          next_char = token[keyword.length]
          next_char.nil? || !next_char.match?(/\p{Ll}/)
        elsif token.end_with?(keyword)
          prev_char = token[-(keyword.length + 1)]
          prev_char.nil? || !prev_char.match?(/\p{Ll}/)
        else
          false
        end
      end)
  end
end
