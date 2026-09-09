# frozen_string_literal: true

require "time"

class TrelloCli::Cli::Card < Thor
  def self.exit_on_failure?
    true
  end

  DUE_FORMAT = "%b %-d, %Y %-l:%M%P"

  # Trello sends `due` in UTC; the caller thinks in local time, so render local.
  # A completed date is never called overdue, however far past it is.
  def self.due_line(card)
    due = Time.parse(card["due"]).getlocal
    text = due.strftime(DUE_FORMAT)
    return "#{text} (complete)" if card["dueComplete"]
    return "#{text} (overdue)" if due < Time.now

    text
  end

  # "a", "a and b", "a, b, and c" — four updatable fields make the plain
  # "and" join read badly.
  def self.sentence(items)
    return items.join(" and ") if items.size <= 2

    "#{items[0..-2].join(', ')}, and #{items.last}"
  end

  desc "archive REF", "Archive a card"
  def archive(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card = TrelloCli::Api::Card.archive(client, config, ref)

    say "Archived: #{card['name']}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "assign REF MEMBER", "Assign a board member to a card"
  def assign(ref, member_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    member = TrelloCli::Api::Card.assign(client, config, ref, member_name)

    say "Assigned: #{TrelloCli::Api::Member.describe(member)}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "unassign REF MEMBER", "Remove a board member from a card"
  def unassign(ref, member_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    member = TrelloCli::Api::Card.unassign(client, config, ref, member_name)

    say "Unassigned: #{TrelloCli::Api::Member.describe(member)}", :green
  rescue ArgumentError, TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "new TITLE", "Create a new card"
  option :description, type: :string, aliases: "-d", desc: "Card description (markdown)"
  option :list, type: :string, aliases: "-l", desc: "List name (defaults to config default_list)"
  option :label, type: :array, aliases: "-L", repeatable: true, default: [],
         desc: "Labels to add, one per value: --label A B or --label A --label B"
  option :position, type: :string, aliases: "-p", desc: "Position in target list (top, bottom, or a number)"
  option :due, type: :string, aliases: "-D",
         desc: "Due date: YYYY-MM-DD, YYYY-MM-DDTHH:MM, today, tomorrow, +Nd, or +Nw"
  def new(title)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card = TrelloCli::Api::Card.create(
      client,
      config,
      title: title,
      description: options[:description],
      list: options[:list],
      labels: Array(options[:label]).flatten,
      position: options[:position],
      due: options[:due]
    )

    say "Created: #{card['shortUrl']}", :green
    say "Card ##{card['idShort']}: #{card['name']}" if card["idShort"]
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "show REF", "Show card details"
  def show(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card = TrelloCli::Api::Card.find(client, config, ref)

    say card["name"], :bold
    say "URL: #{card['shortUrl']}"
    say "List: #{card['list']['name']}" if card["list"]
    say "Due: #{self.class.due_line(card)}" if card["due"]

    if card["members"]&.any?
      say "Members: #{card['members'].map { |m| TrelloCli::Api::Member.display_name(m) }.join(', ')}"
    end

    say ""

    if card["labels"]&.any?
      labels = card["labels"].map { |l| l["name"] }.join(", ")
      say "Labels: #{labels}"
    end

    if card["desc"] && !card["desc"].empty?
      say ""
      say "Description:"
      say card["desc"]
    end

    if card["checklists"]&.any?
      say ""
      say "Checklists:"
      card["checklists"].each do |checklist|
        items = checklist["checkItems"] || []
        completed = items.count { |i| i["state"] == "complete" }
        total = items.size
        progress = total.positive? ? "(#{completed}/#{total})" : ""
        say "  #{checklist['name']}: #{progress}"
        items.sort_by { |i| i["pos"] || 0 }.each do |item|
          status = item["state"] == "complete" ? "[x]" : "[ ]"
          say "    #{status} #{item['name']}"
        end
      end
    end

    if card["attachments"]&.any?
      say ""
      say "Attachments:"
      card["attachments"].each do |att|
        say "  - #{att['name']}"
      end
    end

    if card["actions"]&.any?
      say ""
      say "Comments (#{[card['actions'].length, 3].min} most recent):"
      card["actions"].first(3).each do |comment|
        date = Time.parse(comment["date"]).strftime("%b %d")
        text = comment.dig("data", "text") || ""
        truncated = text.length > 80 ? "#{text[0, 77]}..." : text
        truncated = truncated.gsub(/\s+/, " ")
        say "  #{date}: #{truncated}"
      end
    end
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "move REF LIST", "Move a card to a different list"
  option :position, type: :string, aliases: "-p", desc: "Position in target list (top, bottom, or a number)"
  def move(ref, list_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::Card.move(client, config, ref, list_name, position: options[:position])

    say "Moved to: #{list_name}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "unarchive REF", "Unarchive a card"
  def unarchive(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card = TrelloCli::Api::Card.unarchive(client, config, ref)

    say "Unarchived: #{card['name']}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "update REF", "Update card fields"
  option :description, type: :string, aliases: "-d", desc: "New description (markdown)"
  option :title, type: :string, aliases: "-t", desc: "New title"
  option :due, type: :string, aliases: "-D",
         desc: "Due date: YYYY-MM-DD, YYYY-MM-DDTHH:MM, today, tomorrow, +Nd, +Nw, or none to clear"
  option :due_complete, type: :boolean, desc: "Mark the due date complete (--no-due-complete to undo)"
  # Keyed by flag so the guard, the request and the message all read from one
  # place; a new updatable field is one entry.
  UPDATE_FIELDS = { description: "description", title: "title",
                    due: "due date", due_complete: "due complete" }.freeze

  def update(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    updated = UPDATE_FIELDS.reject { |flag, _| options[flag].nil? }.values
    if updated.empty?
      flags = UPDATE_FIELDS.keys.map { |f| "--#{f.to_s.tr('_', '-')}" }.join(", ")
      say "Error: No update options provided. Use #{flags} to update.", :red
      exit 1
    end

    TrelloCli::Api::Card.update(client, config, ref,
                                description: options[:description], name: options[:title],
                                due: options[:due], due_complete: options[:due_complete])

    say "Updated card #{self.class.sentence(updated)}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "add-label REF LABEL", "Add a label to a card"
  def add_label(ref, label_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::Card.add_label(client, config, ref, label_name)

    say "Added label: #{label_name}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  map "add-label" => :add_label

  desc "remove-label REF LABEL", "Remove a label from a card"
  def remove_label(ref, label_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::Card.remove_label(client, config, ref, label_name)

    say "Removed label: #{label_name}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  map "remove-label" => :remove_label
end
