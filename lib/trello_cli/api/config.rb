# frozen_string_literal: true

require "yaml"

class TrelloCli::Api::Config
  attr_reader :board_id
  attr_reader :default_list
  attr_reader :api_key
  attr_reader :token

  def self.load
    new
  end

  def initialize
    load_file_config
    load_env_config
  end

  private

  def load_file_config
    config_path = config_file_path
    unless File.exist?(config_path)
      raise TrelloCli::ConfigError, ".trello.yml not found at #{config_path}"
    end

    yaml = YAML.safe_load_file(config_path)
    @board_id = yaml["board_id"] or raise TrelloCli::ConfigError, "board_id not found in .trello.yml"
    @default_list = yaml["default_list"] or raise TrelloCli::ConfigError, "default_list not found in .trello.yml"
  end

  def load_env_config
    @api_key = fetch_env("TRELLO_API_KEY")
    @token = fetch_env("TRELLO_TOKEN")
  end

  def fetch_env(key)
    ENV.fetch(key)
  rescue KeyError
    raise TrelloCli::ConfigError, "#{key} not set"
  end

  def config_file_path
    File.join(Dir.pwd, ".trello.yml")
  end
end
