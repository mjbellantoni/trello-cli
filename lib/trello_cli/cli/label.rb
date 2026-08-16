# frozen_string_literal: true

class TrelloCli::Cli::Label < Thor
  COLORS = %w[green yellow orange red purple blue sky lime pink black].freeze

  def self.exit_on_failure?
    true
  end

  desc "list", "List labels on the board"
  def list
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::Label.all(client, config).each do |label|
      name = label["name"].to_s.empty? ? "(unnamed)" : label["name"]
      say "#{name} (#{label['color'] || 'no color'})"
    end
  rescue TrelloCli::Error => e
    say_error "Error: #{e.message}", :red
    exit 1
  end

  desc "new NAME", "Create a label"
  option :color, type: :string, aliases: "-c", required: true, enum: COLORS, desc: "Label color"
  def new(name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::Label.create(client, config, name: name, color: options[:color])

    say "Created label: #{name} (#{options[:color]})", :green
  rescue TrelloCli::Error => e
    say_error "Error: #{e.message}", :red
    exit 1
  end

  desc "rename NAME NEW_NAME", "Rename a label"
  def rename(name, new_name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::Label.rename(client, config, name, new_name)

    say "Renamed label: #{name} -> #{new_name}", :green
  rescue TrelloCli::Error => e
    say_error "Error: #{e.message}", :red
    exit 1
  end

  desc "delete NAME", "Delete a label from the board"
  def delete(name)
    config = TrelloCli::Api::Config.load
    client = TrelloCli::Api::Client.new(config)

    TrelloCli::Api::Label.delete(client, config, name)

    say "Deleted label: #{name}", :green
  rescue TrelloCli::Error => e
    say_error "Error: #{e.message}", :red
    exit 1
  end
end
