# frozen_string_literal: true

# Turns `--after REF` into the `pos` value Trello needs: the midpoint between
# the named card and the one below it, or "bottom" when nothing follows it.
# Resolving it here means one call places a card mid-list, rather than the
# caller reading raw pos values and doing the arithmetic itself.
class TrelloCli::Api::Placement
  CARD_FIELDS = "idShort,shortLink,pos"

  attr_reader :pos
  attr_reader :anchor_number

  # Returns nil when no anchor was asked for, so callers can pass `--after`
  # straight through without branching on it.
  def self.resolve(client, config, list_name, after:, position: nil, moving: nil)
    if after && position
      raise TrelloCli::Error, "--after and --position cannot be used together"
    end
    return nil if after.nil?

    new(client, config, list_name, after, moving)
  end

  def initialize(client, config, list_name, after, moving)
    list = list_name || config.default_list
    anchor_ref = parse_anchor(after)
    moving_ref = moving && TrelloCli::Api::CardRef.parse(moving)
    cards = TrelloCli::Api::List.cards(client, config, list, fields: CARD_FIELDS)

    anchor = cards.find { |card| anchor_ref.matches?(card) }
    raise TrelloCli::NotFoundError, "Card not in list \"#{list}\": #{after}" unless anchor
    raise TrelloCli::Error, "Cannot place a card after itself: #{after}" if moving_ref&.matches?(anchor)

    @anchor_number = anchor["idShort"]
    @pos = position_after(anchor, cards, moving_ref)
  end

  private

  # An unusable reference is caller error, not programmer error: CardRef says
  # so with an ArgumentError, which no command rescues.
  def parse_anchor(after)
    TrelloCli::Api::CardRef.parse(after)
  rescue ArgumentError => e
    raise TrelloCli::Error, e.message
  end

  # Trello spaces cards far apart, so the midpoint between the anchor and the
  # next card along is a free slot between them. The follower is the nearest
  # card strictly below the anchor rather than the next one in order: cards
  # tied with the anchor have no defined order among themselves, so landing
  # inside a tie would not reliably put this card after the anchor at all.
  # The card being moved is left out — its own pos is about to change, so it
  # must not decide where it lands.
  def position_after(anchor, cards, moving_ref)
    anchor_pos = pos_of(anchor)
    candidates = moving_ref ? cards.reject { |card| moving_ref.matches?(card) } : cards
    follower = candidates.select { |card| pos_of(card) > anchor_pos }.min_by { |card| pos_of(card) }
    return "bottom" unless follower

    (anchor_pos + pos_of(follower)) / 2.0
  end

  # Trello sends pos as a number, and the arithmetic above is the first thing
  # in the gem to depend on that. A value it cannot read is worth saying out
  # loud: guessing would misplace the card and still report success.
  def pos_of(card)
    Float(card["pos"])
  rescue ArgumentError, TypeError
    raise TrelloCli::Error, "Card ##{card['idShort']} has an unusable position: #{card['pos'].inspect}"
  end
end
