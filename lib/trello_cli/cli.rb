# frozen_string_literal: true

require "thor"
require_relative "../trello_cli"

class TrelloCli::Cli < Thor
  def self.exit_on_failure?
    true
  end
end

require_relative "cli/card"
require_relative "cli/attach"
require_relative "cli/comment"
require_relative "cli/checklist"
require_relative "cli/list"

class TrelloCli::Cli < Thor
  desc "card SUBCOMMAND", "Manage Trello cards"
  subcommand "card", TrelloCli::Cli::Card

  desc "attach SUBCOMMAND", "Manage card attachments"
  subcommand "attach", TrelloCli::Cli::Attach

  desc "comment SUBCOMMAND", "Manage card comments"
  subcommand "comment", TrelloCli::Cli::Comment

  desc "checklist SUBCOMMAND", "Manage card checklists"
  subcommand "checklist", TrelloCli::Cli::Checklist

  desc "list SUBCOMMAND", "Manage board lists"
  subcommand "list", TrelloCli::Cli::List
end
