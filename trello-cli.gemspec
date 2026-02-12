# frozen_string_literal: true

require_relative "lib/trello_cli/version"

Gem::Specification.new do |spec|
  spec.name = "trello-cli"
  spec.version = TrelloCli::VERSION
  spec.authors = ["MJB"]
  spec.summary = "CLI for Trello API"
  spec.description = "A command-line interface for managing Trello cards, checklists, comments, and attachments"
  spec.homepage = "https://github.com/mjb/trello-cli"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*", "exe/*", "LICENSE", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["trello"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.0"

  spec.metadata["rubygems_mfa_required"] = "true"
end
