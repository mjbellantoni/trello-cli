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

  def self.cards(client, config, name)
    list = find_by_name(client, config, name)
    client.get("/lists/#{list['id']}/cards", { fields: "idShort,name,labels" })
  end

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
