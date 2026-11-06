# frozen_string_literal: true

class TrelloCli::Api::List
  def self.archive(client, config, name)
    list = find_by_name(client, config, name)
    client.put("/lists/#{list['id']}", { closed: true })
  end

  def self.find_by_name(client, config, name)
    lists = client.get("/boards/#{config.board_id}/lists")
    list = lists.find { |l| l["name"] == name }
    raise TrelloCli::NotFoundError, "List not found: #{name}" unless list

    list
  end

  DEFAULT_CARD_FIELDS = "idShort,name,labels"

  def self.cards(client, config, name, fields: DEFAULT_CARD_FIELDS)
    list = find_by_name(client, config, name)
    client.get("/lists/#{list['id']}/cards", { fields: fields })
  end

  DETAIL_PARAMS = {
    fields: "idShort,name,desc,due,dueComplete,labels,shortUrl,idList,pos",
    checklists: "all",
    members: "true", member_fields: "fullName,username",
    attachments: "true", attachment_fields: "name,url"
  }.freeze

  # Everything card show prints but comments, for many cards at once: the
  # cards arrive on one request rather than one each. The lists are fetched
  # too, to name each card's list and to put the cards in board order.
  def self.detailed_cards(client, config, name: nil)
    lists = all(client, config)
    path = if name
             list = lists.find { |l| l["name"] == name }
             raise TrelloCli::NotFoundError, "List not found: #{name}" unless list

             "/lists/#{list['id']}/cards"
           else
             "/boards/#{config.board_id}/cards"
           end

    in_board_order(client.get(path, DETAIL_PARAMS), lists)
  end

  def self.in_board_order(cards, lists)
    rank = lists.each_with_index.to_h { |l, i| [l["id"], i] }
    by_id = lists.to_h { |l| [l["id"], l] }

    cards.sort_by { |c| [rank.fetch(c["idList"], lists.size), c["pos"].to_f] }
         .each { |c| c["list"] = by_id[c["idList"]]&.slice("id", "name") }
  end
  private_class_method :in_board_order

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
