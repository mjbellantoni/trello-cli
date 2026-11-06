# frozen_string_literal: true

class TrelloCli::Api::List
  def self.archive(client, config, name)
    list = find_by_name(client, config, name)
    client.put("/lists/#{list['id']}", { closed: true })
  end

  def self.find_by_name(client, config, name)
    find_in(all(client, config), name)
  end

  def self.find_in(lists, name)
    lists.find { |l| l["name"] == name } || raise(TrelloCli::NotFoundError, "List not found: #{name}")
  end
  private_class_method :find_in

  def self.cards(client, config, name, fields:)
    list = find_by_name(client, config, name)
    client.get("/lists/#{list['id']}/cards", { fields: fields })
  end

  # What a line of output prints, plus what puts the cards in board order.
  # For everything a card carries, pass TrelloCli::Api::Card::DETAIL_PARAMS.
  SUMMARY_PARAMS = { fields: "idShort,name,labels,idList,pos" }.freeze

  # The named list's cards, or with no name every card on the board, each
  # carrying its list's id and name as a single card read does. The cards
  # arrive on one request however many there are; the lists are fetched too,
  # to find and name each card's list and to put the cards in board order.
  def self.cards_in_board_order(client, config, name: nil, params: SUMMARY_PARAMS)
    lists = all(client, config)
    path = name ? "/lists/#{find_in(lists, name)['id']}/cards" : "/boards/#{config.board_id}/cards"

    with_lists_in_board_order(client.get(path, params), lists)
  end

  # Returns copies, each with a "list" key added; a card whose list is not
  # among the open ones goes last, with a nil list.
  def self.with_lists_in_board_order(cards, lists)
    rank = lists.each_with_index.to_h { |l, i| [l["id"], i] }
    by_id = lists.to_h { |l| [l["id"], l.slice("id", "name")] }

    # pos is read leniently on purpose: it only orders what is printed, and a
    # listing of the whole board must not fail over one card's position.
    # Placement#pos_of is strict because it does arithmetic with pos and
    # writes the result back, where a bad value would misplace a card.
    cards.sort_by { |c| [rank.fetch(c["idList"], lists.size), c["pos"].to_f] }
         .map { |c| c.merge("list" => by_id[c["idList"]]) }
  end
  private_class_method :with_lists_in_board_order

  # with_counts embeds each list's open cards in this same response. Counting
  # them per list would turn one request into one per list.
  def self.all(client, config, with_counts: false)
    params = with_counts ? { cards: "open", card_fields: "id" } : {}
    client.get("/boards/#{config.board_id}/lists", params)
  end

  def self.unarchive(client, config, name)
    lists = client.get("/boards/#{config.board_id}/lists", { filter: "closed" })
    list = lists.find { |l| l["name"] == name }
    raise TrelloCli::NotFoundError, "Archived list not found: #{name}" unless list

    client.put("/lists/#{list['id']}", { closed: false })
  end
end
