# frozen_string_literal: true

class TrelloCli::Api::CardRef
  attr_reader :short_link
  attr_reader :card_number

  TRELLO_URL_PATTERN = %r{trello\.com/c/([a-zA-Z0-9]+)}.freeze
  CARD_NUMBER_PATTERN = /\A#?(\d+)\z/.freeze

  def self.parse(input)
    new(input)
  end

  def initialize(input)
    @input = input.to_s.strip
    raise ArgumentError, "Card reference cannot be empty" if @input.empty?

    parse_input
  end

  def to_api_id(client, config)
    if short_link
      short_link
    elsif card_number
      card = client.get("/boards/#{config.board_id}/cards/#{card_number}")
      card["id"]
    end
  end

  private

  def parse_input
    if (match = @input.match(TRELLO_URL_PATTERN))
      @short_link = match[1]
    elsif (match = @input.match(CARD_NUMBER_PATTERN))
      @card_number = match[1].to_i
    else
      @short_link = @input
    end
  end
end
