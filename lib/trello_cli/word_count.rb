# frozen_string_literal: true

# Counts the words a reader actually reads. Structural markdown is stripped
# first: markers are not words. Heading text is kept, and so is fenced content —
# excluding it would let a caller defeat the cap with backticks.
module TrelloCli
  class WordCount
    FENCE = /^\s*```.*$/.freeze
    LIST_MARKER = /^\s*(?:[-*+]|\d+\.)\s+/.freeze
    HEADING_MARKER = /^\s*#+\s*/.freeze
    EDGE_EMPHASIS = /\A[*_]+|[*_]+\z/.freeze

    def self.count(text)
      return 0 if text.nil?

      text.lines
          .reject { |line| line.match?(FENCE) }
          .map { |line| line.sub(HEADING_MARKER, "").sub(LIST_MARKER, "") }
          .join(" ")
          .split(/\s+/)
          .map { |token| token.gsub(EDGE_EMPHASIS, "") }
          .count { |token| !token.empty? }
    end
  end
end
