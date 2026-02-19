# frozen_string_literal: true

class TrelloCli::Api::Card
  def self.archive(client, config, card_ref)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    client.put("/cards/#{card_id}", { closed: true })
  end

  def self.find(client, config, card_ref)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    client.get("/cards/#{card_id}", { checklists: "all", attachments: "true", actions: "commentCard" })
  end

  def self.create(client, config, title:, description: nil, list: nil, labels: [], position: nil)
    list_name = list || config.default_list
    list_data = TrelloCli::Api::List.find_by_name(client, config, list_name)

    body = {
      name: title,
      idList: list_data["id"],
      idBoard: config.board_id
    }
    body[:desc] = description if description
    body[:idLabels] = resolve_labels(client, config, labels).join(",") if labels.any?
    body[:pos] = position if position

    client.post("/cards", body)
  end

  def self.move(client, config, card_ref, list_name)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    list_data = TrelloCli::Api::List.find_by_name(client, config, list_name)
    client.put("/cards/#{card_id}", { idList: list_data["id"] })
  end

  def self.update(client, config, card_ref, description:)
    ref = card_ref.is_a?(TrelloCli::Api::CardRef) ? card_ref : TrelloCli::Api::CardRef.parse(card_ref)
    card_id = ref.to_api_id(client, config)
    client.put("/cards/#{card_id}", { desc: description })
  end

  def self.resolve_labels(client, config, label_names)
    board_labels = client.get("/boards/#{config.board_id}/labels")
    label_names.map do |name|
      label = board_labels.find { |l| l["name"].downcase == name.downcase }
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
