# frozen_string_literal: true

class TrelloCli::Cli::Checklist < Thor
  def self.exit_on_failure?
    true
  end

  desc "add REF NAME", "Add a checklist to a card"
  def add(ref, name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    TrelloCli::Api::Checklist.add(client, card_id, name)

    say "Checklist added: #{name}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "remove REF NAME", "Remove a checklist from a card"
  def remove(ref, name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, name)
    TrelloCli::Api::Checklist.remove(client, checklist["id"])

    say "Checklist removed: #{name}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "rename REF NAME NEW_NAME", "Rename a checklist"
  def rename(ref, name, new_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, name)
    TrelloCli::Api::Checklist.rename(client, checklist["id"], new_name)

    say "Checklist renamed: #{name} -> #{new_name}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-add REF CHECKLIST ITEM", "Add an item to a checklist"
  map "item-add" => :item_add
  def item_add(ref, checklist_name, item_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    TrelloCli::Api::Checklist.add_item(client, checklist["id"], item_name)

    say "Item added: #{item_name}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-edit REF CHECKLIST ITEM NEW_TEXT", "Edit a checklist item"
  map "item-edit" => :item_edit
  def item_edit(ref, checklist_name, item_ref, new_text)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    item = TrelloCli::Api::Checklist.find_item(checklist, item_ref)
    TrelloCli::Api::Checklist.update_item(client, card_id, item["id"], name: new_text)

    say "Item updated: #{new_text}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-check REF CHECKLIST ITEM", "Mark a checklist item complete"
  map "item-check" => :item_check
  def item_check(ref, checklist_name, item_ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    item = TrelloCli::Api::Checklist.find_item(checklist, item_ref)
    TrelloCli::Api::Checklist.update_item(client, card_id, item["id"], state: "complete")

    say "Item checked: #{item['name']}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-uncheck REF CHECKLIST ITEM", "Mark a checklist item incomplete"
  map "item-uncheck" => :item_uncheck
  def item_uncheck(ref, checklist_name, item_ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    item = TrelloCli::Api::Checklist.find_item(checklist, item_ref)
    TrelloCli::Api::Checklist.update_item(client, card_id, item["id"], state: "incomplete")

    say "Item unchecked: #{item['name']}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "item-remove REF CHECKLIST ITEM", "Remove a checklist item"
  map "item-remove" => :item_remove
  def item_remove(ref, checklist_name, item_ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card_ref = TrelloCli::Api::CardRef.parse(ref)
    card_id = card_ref.to_api_id(client, config)

    checklist = TrelloCli::Api::Checklist.find_by_name(client, card_id, checklist_name)
    item = TrelloCli::Api::Checklist.find_item(checklist, item_ref)
    TrelloCli::Api::Checklist.remove_item(client, checklist["id"], item["id"])

    say "Item removed: #{item['name']}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end
end
