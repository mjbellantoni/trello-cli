# frozen_string_literal: true

class TrelloCli::Api::Checklist
  def self.add(client, card_id, name)
    raise ArgumentError, "Checklist name cannot be blank" if name.nil? || name.strip.empty?

    client.post("/cards/#{card_id}/checklists", { name: name })
  end

  def self.remove(client, checklist_id)
    client.delete("/checklists/#{checklist_id}")
  end

  def self.rename(client, checklist_id, name)
    raise ArgumentError, "Checklist name cannot be blank" if name.nil? || name.strip.empty?

    client.put("/checklists/#{checklist_id}", { name: name })
  end

  def self.find_by_name(client, card_id, name)
    card = client.get("/cards/#{card_id}", { checklists: "all" })
    checklists = (card["checklists"] || []).select { |cl| cl["name"] == name }

    raise TrelloCli::NotFoundError, "Checklist not found: #{name}" if checklists.empty?
    raise TrelloCli::Error, "Multiple checklists named '#{name}' on this card" if checklists.size > 1

    checklists.first
  end

  def self.add_item(client, checklist_id, name)
    raise ArgumentError, "Item name cannot be blank" if name.nil? || name.strip.empty?

    client.post("/checklists/#{checklist_id}/checkItems", { name: name })
  end

  def self.update_item(client, card_id, item_id, attrs)
    client.put("/cards/#{card_id}/checkItem/#{item_id}", attrs)
  end

  def self.remove_item(client, checklist_id, item_id)
    client.delete("/checklists/#{checklist_id}/checkItems/#{item_id}")
  end

  def self.find_item(checklist, item_ref)
    items = (checklist["checkItems"] || []).sort_by { |i| i["pos"] || 0 }

    if item_ref.match?(/\A\d+\z/)
      pos = item_ref.to_i
      raise ArgumentError, "Position #{pos} is out of range (1-#{items.size})" if pos < 1 || pos > items.size

      items[pos - 1]
    else
      item = items.find { |i| i["name"] == item_ref }
      raise TrelloCli::NotFoundError, "Item not found: #{item_ref}" unless item

      item
    end
  end
end
