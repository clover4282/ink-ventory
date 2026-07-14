class CatalogSearch
  def self.match?(text, query)
    score(text, query).positive?
  end

  def self.score(text, query)
    normalized_text = text.unicode_normalize(:nfc).downcase
    candidates = words(normalized_text)
    terms = words(query)
    score = normalized_text.include?(query.to_s.unicode_normalize(:nfc).downcase.squish) ? 100 : 0

    terms.each do |term|
      if normalized_text.include?(term)
        score += 10
      elsif candidates.any? { |candidate| similar?(term, candidate) }
        score += 1
      else
        return 0
      end
    end
    score
  end

  def self.words(text)
    text.to_s.unicode_normalize(:nfc).downcase.scan(/[[:alpha:]]+|[[:digit:]]+/)
  end
  private_class_method :words

  def self.similar?(term, candidate)
    left = term.unicode_normalize(:nfd).chars
    right = candidate.unicode_normalize(:nfd).chars
    limit = left.length >= 6 ? 2 : left.length >= 3 ? 1 : 0
    return false if (left.length - right.length).abs > limit

    distance(left, right) <= limit
  end
  private_class_method :similar?

  def self.distance(left, right)
    previous = (0..right.length).to_a
    left.each_with_index do |left_character, left_index|
      current = [ left_index + 1 ]
      right.each_with_index do |right_character, right_index|
        current << [
          current[right_index] + 1,
          previous[right_index + 1] + 1,
          previous[right_index] + (left_character == right_character ? 0 : 1)
        ].min
      end
      previous = current
    end
    previous.last
  end
  private_class_method :distance
end
