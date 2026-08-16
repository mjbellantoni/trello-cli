# frozen_string_literal: true

# Translates position input (top, bottom, or a number) into the value the Trello
# API expects. Shared by cards and lists so both accept the same grammar.
class TrelloCli::Api::Position
  KEYWORDS = %w[top bottom].freeze

  def self.parse(position)
    return position if KEYWORDS.include?(position)
    return Float(position) if position.match?(/\A-?\d+(\.\d+)?\z/)

    raise TrelloCli::Error, "Invalid position: #{position} (expected top, bottom, or a number)"
  end
end
