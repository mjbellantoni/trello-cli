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
    anchor_ref = TrelloCli::Api::CardRef.parse(after)
    moving_ref = moving && TrelloCli::Api::CardRef.parse(moving)
    cards = TrelloCli::Api::List.cards(client, config, list, fields: CARD_FIELDS)

    anchor = cards.find { |card| anchor_ref.matches?(card) }
    raise TrelloCli::NotFoundError, "Card not in list \"#{list}\": #{after}" unless anchor
    raise TrelloCli::Error, "Cannot place a card after itself: #{after}" if moving_ref&.matches?(anchor)

    @anchor_number = anchor["idShort"]
    @pos = position_after(anchor, cards, moving_ref)
  end

  private

  # Trello spaces cards far apart, so the midpoint between two neighbours is
  # always a free slot between them. The card being moved is left out: its own
  # pos is about to change, so it must not decide where it lands.
  def position_after(anchor, cards, moving_ref)
    ordered = cards.sort_by { |card| card["pos"] }
    ordered = ordered.reject { |card| moving_ref.matches?(card) } if moving_ref
    follower = ordered[ordered.index(anchor) + 1]
    return "bottom" unless follower

    (anchor["pos"] + follower["pos"]) / 2.0
  end
end
