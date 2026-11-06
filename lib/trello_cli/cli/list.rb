# frozen_string_literal: true

class TrelloCli::Cli::List < Thor
  def self.exit_on_failure?
    true
  end

  desc "all", "List all lists on the board"
  option :format, type: :string, aliases: "-f", enum: %w[id id-name name], desc: "Output format (id, name, id-name)"
  option :count, type: :boolean, aliases: "-c", desc: "Append the number of open cards in each list"
  def all
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    lists = TrelloCli::Api::List.all(client, config, with_counts: options[:count] == true)

    lists.each do |list|
      line = case options[:format]
             when "id" then list["id"]
             when "id-name" then "#{list['id']} #{list['name']}"
             else list["name"]
             end
      line = "#{line} (#{(list['cards'] || []).size})" if options[:count]
      say line
    end
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "cards [NAME]", "List cards in a list, or on the whole board with --all"
  option :format, type: :string, aliases: "-f", enum: %w[id id-name name], desc: "Output format (id, name, id-name)"
  option :with_label, type: :string, aliases: "-L", desc: "Only show cards with this label"
  option :without_label, type: :string, aliases: "-X", desc: "Exclude cards with this label"
  option :all, type: :boolean, aliases: "-a", desc: "List cards from every list on the board instead of one"
  option :json, type: :boolean,
                desc: "Print each card's details (everything card show prints but comments) as a JSON array"
  def cards(name = nil)
    usage_error = cards_usage_error(name)
    if usage_error
      say "Error: #{usage_error}", :red
      exit 1
    end

    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    cards = if options[:json] || options[:all]
              TrelloCli::Api::List.detailed_cards(client, config, name: name)
            else
              TrelloCli::Api::List.cards(client, config, name)
            end

    if options[:with_label]
      label = options[:with_label].dup.force_encoding("UTF-8").downcase
      cards = cards.select { |c| (c["labels"] || []).any? { |l| l["name"].downcase == label } }
    end

    if options[:without_label]
      label = options[:without_label].dup.force_encoding("UTF-8").downcase
      cards = cards.reject { |c| (c["labels"] || []).any? { |l| l["name"].downcase == label } }
    end

    if options[:json]
      puts JSON.generate(cards.map { |card| TrelloCli::CardJson.from(card) })
      return
    end

    cards.each do |card|
      case options[:format]
      when "id"
        say "##{card['idShort']}"
      when "name"
        say card["name"]
      else
        say "##{card['idShort']} #{card['name']}"
      end
    end
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  no_commands do
    def cards_usage_error(name)
      return "give a list NAME or --all, not both" if name && options[:all]
      return "give a list NAME or --all" unless name || options[:all]
      return "--with-label and --without-label are mutually exclusive" if options[:with_label] && options[:without_label]

      "--format and --json are mutually exclusive" if options[:format] && options[:json]
    end
  end

  desc "archive NAME", "Archive a list"
  def archive(name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::List.archive(client, config, name)

    say "Archived: #{name}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end

  desc "unarchive NAME", "Unarchive a list"
  def unarchive(name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::List.unarchive(client, config, name)

    say "Unarchived: #{name}", :green
  rescue TrelloCli::Error => e
    say "Error: #{e.message}", :red
    exit 1
  end
end
