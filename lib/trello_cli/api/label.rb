# frozen_string_literal: true

class TrelloCli::Api::Label
  def self.all(client, config)
    client.get("/boards/#{config.board_id}/labels")
  end

  def self.normalize(name)
    name.to_s.dup.force_encoding("UTF-8").downcase
  end

  def self.find_in(labels, name)
    normalized = normalize(name)
    labels.find { |l| l["name"].to_s.downcase == normalized }
  end

  def self.duplicate_error(name)
    TrelloCli::Error.new("Label already exists: #{name}. Names must be unique to stay addressable.")
  end

  def self.find_by_name(client, config, name)
    label = find_in(all(client, config), name)
    raise TrelloCli::NotFoundError, "Label not found: #{name}" unless label

    label
  end

  def self.exists?(client, config, name)
    # Trello boards ship with colour-only labels whose name is "". Uniqueness
    # exists to keep labels addressable by name, and a blank name never was,
    # so refusing a second one would block a legitimate operation for nothing.
    return false if normalize(name).strip.empty?

    !find_in(all(client, config), name).nil?
  end

  def self.create(client, config, name:, color:)
    raise duplicate_error(name) if exists?(client, config, name)

    client.post("/labels", { name: name, color: color, idBoard: config.board_id })
  end

  def self.rename(client, config, name, new_name)
    # A blank target is refused here even though create allows one. Renaming a
    # named label to "" destroys the only handle it can be found by again;
    # creating a colour-only label never had such a handle to lose.
    if normalize(new_name).strip.empty?
      raise TrelloCli::Error,
            "Label name cannot be blank: labels are addressed by name, " \
            "so \"#{name}\" could not be found again."
    end

    labels = all(client, config)
    label = find_in(labels, name)
    raise TrelloCli::NotFoundError, "Label not found: #{name}" unless label

    # Collision is decided by identity, not by name — a label must never be
    # found to collide with itself, or a pure case change would be impossible.
    clash = find_in(labels, new_name)
    raise duplicate_error(new_name) if clash && clash["id"] != label["id"]

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

  private_class_method :normalize, :find_in, :duplicate_error
end
