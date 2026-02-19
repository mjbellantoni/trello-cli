# frozen_string_literal: true

class TrelloCli::Cli::List < Thor
  def self.exit_on_failure?
    true
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
