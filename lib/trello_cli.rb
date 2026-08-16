# frozen_string_literal: true

require_relative "trello_cli/version"

module TrelloCli
  class Error < StandardError; end
  class ConfigError < Error; end
  class NotFoundError < Error; end
  class AuthError < Error; end
end

require_relative "trello_cli/word_count"
require_relative "trello_cli/kinds"
require_relative "trello_cli/kind_description"
require_relative "trello_cli/kind_validator"

require_relative "trello_cli/api"
require_relative "trello_cli/api/config"
require_relative "trello_cli/api/client"
require_relative "trello_cli/api/card_ref"
require_relative "trello_cli/api/position"
require_relative "trello_cli/api/list"
require_relative "trello_cli/api/member"
require_relative "trello_cli/api/card"
require_relative "trello_cli/api/label"
require_relative "trello_cli/api/attachment"
require_relative "trello_cli/api/comment"
require_relative "trello_cli/api/checklist"
