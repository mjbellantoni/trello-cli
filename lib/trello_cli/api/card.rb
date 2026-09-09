# frozen_string_literal: true

class TrelloCli::Api::Card
  def self.add_label(client, config, card_ref, label_name)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    label_id = resolve_labels(client, config, [label_name]).first
    client.post("/cards/#{card_id}/idLabels", { value: label_id })
  end

  def self.remove_label(client, config, card_ref, label_name)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    card = client.get("/cards/#{card_id}", { fields: "labels" })
    utf8_name = label_name.dup.force_encoding("UTF-8")
    label = (card["labels"] || []).find { |l| l["name"].downcase == utf8_name.downcase }
    raise TrelloCli::NotFoundError, "Label not found on card: #{label_name}" unless label

    client.delete("/cards/#{card_id}/idLabels/#{label['id']}")
  end

  # Idempotent: Trello rejects a POST for a member already on the card, and an
  # agent retrying an assign should not see that as a failure.
  def self.assign(client, config, card_ref, member_name)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    member = TrelloCli::Api::Member.find_by_name(client, config, member_name)

    card = client.get("/cards/#{card_id}", { fields: "idMembers" })
    unless (card["idMembers"] || []).include?(member["id"])
      client.post("/cards/#{card_id}/idMembers", { value: member["id"] })
    end

    member
  end

  # No pre-check here: DELETE is already idempotent, so removing a member who
  # is not on the card is a no-op rather than an error.
  def self.unassign(client, config, card_ref, member_name)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    member = TrelloCli::Api::Member.find_by_name(client, config, member_name)

    client.delete("/cards/#{card_id}/idMembers/#{member['id']}")

    member
  end

  def self.archive(client, config, card_ref)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    client.put("/cards/#{card_id}", { closed: true })
  end

  def self.find(client, config, card_ref)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    # list and members ride along on this request rather than costing their own.
    client.get("/cards/#{card_id}",
               { checklists: "all", attachments: "true", actions: "commentCard",
                 list: "true", members: "true" })
  end

  def self.create(client, config, title:, description: nil, list: nil, labels: [], position: nil, due: nil)
    list_name = list || config.default_list
    list_data = TrelloCli::Api::List.find_by_name(client, config, list_name)

    body = {
      name: title,
      idList: list_data["id"],
      idBoard: config.board_id
    }
    body[:desc] = description if description
    body[:idLabels] = resolve_labels(client, config, labels).join(",") if labels.any?
    body[:pos] = TrelloCli::Api::Position.parse(position) unless position.nil?
    body[:due] = TrelloCli::Api::DueDate.parse(due) unless due.nil?

    client.post("/cards", body)
  end

  def self.move(client, config, card_ref, list_name, position: nil)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    list_data = TrelloCli::Api::List.find_by_name(client, config, list_name)
    body = { idList: list_data["id"] }
    body[:pos] = TrelloCli::Api::Position.parse(position) unless position.nil?
    client.put("/cards/#{card_id}", body)
  end

  # A nil `due` leaves the date alone; "none" parses to nil and is sent as
  # `due: null`, which is how Trello clears it.
  def self.update(client, config, card_ref, description: nil, name: nil, due: nil, due_complete: nil)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    body = {}
    body[:desc] = description unless description.nil?
    body[:name] = name unless name.nil?
    body[:due] = TrelloCli::Api::DueDate.parse(due) unless due.nil?
    body[:dueComplete] = due_complete unless due_complete.nil?
    client.put("/cards/#{card_id}", body)
  end

  def self.resolve_labels(client, config, label_names)
    board_labels = client.get("/boards/#{config.board_id}/labels")
    label_names.map do |name|
      utf8_name = name.dup.force_encoding("UTF-8")
      label = board_labels.find { |l| l["name"].downcase == utf8_name.downcase }
      raise TrelloCli::NotFoundError, "Label not found: #{name}" unless label

      label["id"]
    end
  end

  def self.unarchive(client, config, card_ref)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    client.put("/cards/#{card_id}", { closed: false })
  end
end
