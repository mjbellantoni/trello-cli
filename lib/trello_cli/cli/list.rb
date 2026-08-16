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

  desc "cards NAME", "List cards in a list"
  option :format, type: :string, aliases: "-f", enum: %w[id id-name name], desc: "Output format (id, name, id-name)"
  option :with_label, type: :string, aliases: "-L", desc: "Only show cards with this label"
  option :without_label, type: :string, aliases: "-X", desc: "Exclude cards with this label"
  def cards(name)
    if options[:with_label] && options[:without_label]
      say "Error: --with-label and --without-label are mutually exclusive", :red
      exit 1
    end

    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    cards = TrelloCli::Api::List.cards(client, config, name)

    if options[:with_label]
      label = options[:with_label].dup.force_encoding("UTF-8").downcase
      cards = cards.select { |c| (c["labels"] || []).any? { |l| l["name"].downcase == label } }
    end

    if options[:without_label]
      label = options[:without_label].dup.force_encoding("UTF-8").downcase
      cards = cards.reject { |c| (c["labels"] || []).any? { |l| l["name"].downcase == label } }
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
