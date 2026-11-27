module InstructionCleanupV1
  STANDALONE_MARKER = /\A(?:step[[:space:]]*[0-9]+[[:space:]]*[.():-]?|[0-9]+[[:space:]]*[.():-]?|▢|[\u200B\uFEFF]+)\z/i
  NUMBERED_PREFIX = /\A([0-9]+)[.)][[:space:]]+(?=[[:alpha:]])/

  def self.standalone_marker?(text)
    STANDALONE_MARKER.match?(text.to_s.strip)
  end

  def self.without_numbered_prefixes(texts)
    return texts if texts.size < 2

    sequential = texts.each_with_index.all? do |text, index|
      text.to_s[NUMBERED_PREFIX, 1] == (index + 1).to_s
    end
    return texts unless sequential

    texts.map { |text| text.sub(NUMBERED_PREFIX, "") }
  end

  ZERO_PADDED_PREFIX = /\A(0[1-9][0-9]*)\.[[:space:]]*(?=[[:alpha:]])/

  def self.without_zero_padded_prefixes(texts)
    return texts if texts.size < 3

    sequential = texts.each_with_index.all? do |text, index|
      prefix = text.to_s[ZERO_PADDED_PREFIX, 1]
      (index.zero? && prefix.nil?) || (prefix && prefix.to_i == index + 1)
    end
    return texts unless sequential

    texts.map { |text| text&.sub(ZERO_PADDED_PREFIX, "") }
  end
end
