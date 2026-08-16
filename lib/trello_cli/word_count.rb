# frozen_string_literal: true

# Counts the words a reader actually reads. Structural markdown is stripped
# first: markers are not words. Heading text is kept, and so is fenced content —
# excluding it would let a caller defeat the cap with backticks.
module TrelloCli
  class WordCount
    FENCE = /^\s*```.*$/.freeze
    LIST_MARKER = /^\s*(?:[-*+]|\d+\.)\s+/.freeze
    HEADING_MARKER = /^\s*#+\s*/.freeze
    EMPHASIS = /[*_]{1,3}/.freeze

    def self.count(text)
      return 0 if text.nil?

      stripped = text.lines.reject { |line| line.match?(FENCE) }.map do |line|
        line.sub(HEADING_MARKER, "").sub(LIST_MARKER, "")
      end.join(" ")

      stripped.gsub(EMPHASIS, " ").split(/\s+/).count { |token| !token.empty? }
    end
  end
end
