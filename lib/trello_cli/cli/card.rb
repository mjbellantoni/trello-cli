# frozen_string_literal: true

class TrelloCli::Cli::Card < Thor
  def self.exit_on_failure?
    true
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

  desc "new TITLE", "Create a new card"
  option :description, type: :string, aliases: "-d", desc: "Card description (markdown)"
  option :list, type: :string, aliases: "-l", desc: "List name (defaults to config default_list)"
  option :label, type: :array, aliases: "-L", default: [], desc: "Labels to add (repeatable)"
  option :position, type: :string, aliases: "-p", enum: %w[top bottom], desc: "Position in list (top or bottom)"
  def new(title)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    card = TrelloCli::Api::Card.create(
      client,
      config,
      title: title,
      description: options[:description],
      list: options[:list],
      labels: options[:label],
      position: options[:position]
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
  def move(ref, list_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::Card.move(client, config, ref, list_name)

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
  def update(ref)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    if options[:description].nil?
      say "Error: No update options provided. Use --description to update.", :red
      exit 1
    end

    TrelloCli::Api::Card.update(client, config, ref, description: options[:description])

    say "Updated card description", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end
end
