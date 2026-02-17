# frozen_string_literal: true

require "yaml"

# Loads configuration from .trello.yml (project, then home), with ENV overrides.
class TrelloCli::Api::Config
  CONFIG_FILES = [
    File.join(Dir.pwd, ".trello.yml"),
    File.join(Dir.home, ".trello.yml")
  ].freeze

  def self.load
    path = CONFIG_FILES.find { |p| File.exist?(p) }
    file_config = path ? YAML.safe_load_file(path) : {}

    file_config.each do |key, value|
      ENV[key] ||= value.to_s
    end

    new
  end

  def self.fetch(key, default = nil)
    ENV.fetch(key, default)
  end

  def api_key
    ENV["TRELLO_API_KEY"]
  end

  def board_id
    ENV["TRELLO_DEFAULT_BOARD_ID"]
  end

  def default_list
    ENV["TRELLO_DEFAULT_LIST"]
  end

  def token
    ENV["TRELLO_TOKEN"]
  end
end
