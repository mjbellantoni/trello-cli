# frozen_string_literal: true

class TrelloCli::Api::Label
  def self.all(client, config)
    client.get("/boards/#{config.board_id}/labels")
  end

  def self.find_by_name(client, config, name)
    utf8 = name.dup.force_encoding("UTF-8").downcase
    label = all(client, config).find { |l| l["name"].to_s.downcase == utf8 }
    raise TrelloCli::NotFoundError, "Label not found: #{name}" unless label

    label
  end

  def self.exists?(client, config, name)
    utf8 = name.to_s.dup.force_encoding("UTF-8").downcase
    # Trello boards ship with colour-only labels whose name is "". Uniqueness
    # exists to keep labels addressable by name, and a blank name never was,
    # so refusing a second one would block a legitimate operation for nothing.
    return false if utf8.strip.empty?

    all(client, config).any? { |l| l["name"].to_s.downcase == utf8 }
  end

  def self.create(client, config, name:, color:)
    if exists?(client, config, name)
      raise TrelloCli::Error, "Label already exists: #{name}. Names must be unique to stay addressable."
    end

    client.post("/labels", { name: name, color: color, idBoard: config.board_id })
  end

  def self.rename(client, config, name, new_name)
    label = find_by_name(client, config, name)
    if exists?(client, config, new_name)
      raise TrelloCli::Error, "Label already exists: #{new_name}. Names must be unique to stay addressable."
    end

    client.put("/labels/#{label['id']}", { name: new_name })
  end

  def self.cards_using(client, config, label_id)
    # filter: "all" is load-bearing. The endpoint returns only OPEN cards by
    # default, so a label living solely on archived cards would count as zero
    # and be deleted silently — stripping it from cards that can be unarchived.
    cards = client.get("/boards/#{config.board_id}/cards", { fields: "labels", filter: "all" })
    cards.count { |card| (card["labels"] || []).any? { |l| l["id"] == label_id } }
  end

  def self.delete(client, config, name)
    label = find_by_name(client, config, name)
    count = cards_using(client, config, label["id"])

    if count.positive? && ENV["TRELLO_ALLOW_LABEL_DELETE_IN_USE"] != "true"
      raise TrelloCli::Error,
            "\"#{name}\" is on #{count} card#{'s' if count != 1}. Deleting removes it from all of them.\n" \
            "Set TRELLO_ALLOW_LABEL_DELETE_IN_USE=true to permit this."
    end

    client.delete("/labels/#{label['id']}")
  end
end
