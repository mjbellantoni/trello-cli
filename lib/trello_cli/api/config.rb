# frozen_string_literal: true

require "yaml"

# Loads configuration from .trello.yml (project, then home), with ENV overrides.
class TrelloCli::Api::Config
  CONFIG_FILES = [
    File.join(Dir.pwd, ".trello.yml"),
    File.join(Dir.home, ".trello.yml")
  ].freeze

  DEFAULT_WORD_CAPS = { bug: 200, feature: 150, chore: 150 }.freeze

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

  def word_cap_for(kind)
    override = ENV["TRELLO_#{kind.to_s.upcase}_WORD_CAP"]
    return DEFAULT_WORD_CAPS.fetch(kind) if override.nil? || override.empty?

    Integer(override)
  end

  def label_for(kind)
    override = ENV["TRELLO_#{kind.to_s.upcase}_LABEL"]
    return kind.to_s if override.nil? || override.empty?

    override
  end
end
