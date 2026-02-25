# frozen_string_literal: true

require "spec_helper"
require "trello_cli/cli"
require "json"

RSpec.describe TrelloCli::CommandCatalog do
  let(:catalog) { described_class.generate }

  describe ".generate" do
    it "returns valid JSON-serializable hash" do
      json = JSON.generate(catalog)
      parsed = JSON.parse(json)
      expect(parsed).to eq(catalog)
    end

    it "includes schema_version" do
      expect(catalog["schema_version"]).to eq("1")
    end

    it "includes cli_version" do
      expect(catalog["cli_version"]).to eq(TrelloCli::VERSION)
    end

    it "includes a non-empty commands array" do
      expect(catalog["commands"]).to be_an(Array)
      expect(catalog["commands"]).not_to be_empty
    end

    it "produces deterministic output" do
      first = JSON.generate(described_class.generate)
      second = JSON.generate(described_class.generate)
      expect(first).to eq(second)
    end
  end

  describe "known commands" do
    it "includes card new with expected args and options" do
      cmd = catalog["commands"].find { |c| c["name"] == "card new" }
      expect(cmd).not_to be_nil
      expect(cmd["summary"]).to eq("Create a new card")
      expect(cmd["args"].map { |a| a["name"] }).to include("TITLE")
      expect(cmd["options"].map { |o| o["name"] }).to include("--description", "--list", "--label", "--position")
    end

    it "includes card show" do
      cmd = catalog["commands"].find { |c| c["name"] == "card show" }
      expect(cmd).not_to be_nil
      expect(cmd["args"].map { |a| a["name"] }).to eq(["REF"])
    end

    it "includes card move" do
      cmd = catalog["commands"].find { |c| c["name"] == "card move" }
      expect(cmd).not_to be_nil
      expect(cmd["args"].map { |a| a["name"] }).to eq(%w[REF LIST])
    end

    it "includes checklist item-add with hyphenated name" do
      cmd = catalog["commands"].find { |c| c["name"] == "checklist item-add" }
      expect(cmd).not_to be_nil
      expect(cmd["args"].map { |a| a["name"] }).to eq(%w[REF CHECKLIST ITEM])
    end

    it "includes attach get with output option" do
      cmd = catalog["commands"].find { |c| c["name"] == "attach get" }
      expect(cmd).not_to be_nil
      expect(cmd["options"].map { |o| o["name"] }).to include("--output")
    end

    it "includes comment add" do
      cmd = catalog["commands"].find { |c| c["name"] == "comment add" }
      expect(cmd).not_to be_nil
      expect(cmd["args"].map { |a| a["name"] }).to eq(%w[REF TEXT])
    end

    it "includes list archive" do
      cmd = catalog["commands"].find { |c| c["name"] == "list archive" }
      expect(cmd).not_to be_nil
    end
  end

  describe "command shape" do
    let(:required_keys) { %w[aliases args examples name options outputs summary] }

    it "every command has all required keys" do
      catalog["commands"].each do |cmd|
        required_keys.each do |key|
          expect(cmd).to have_key(key), "Command '#{cmd['name']}' missing key '#{key}'"
        end
      end
    end

    it "commands are sorted alphabetically by name" do
      names = catalog["commands"].map { |c| c["name"] }
      expect(names).to eq(names.sort)
    end

    it "every command has at least one example" do
      catalog["commands"].each do |cmd|
        expect(cmd["examples"]).not_to be_empty, "Command '#{cmd['name']}' has no examples"
      end
    end

    it "every option has required fields" do
      catalog["commands"].each do |cmd|
        cmd["options"].each do |opt|
          %w[name required type summary].each do |key|
            expect(opt).to have_key(key),
              "Option '#{opt['name']}' in '#{cmd['name']}' missing key '#{key}'"
          end
        end
      end
    end

    it "option names start with --" do
      catalog["commands"].each do |cmd|
        cmd["options"].each do |opt|
          expect(opt["name"]).to start_with("--"),
            "Option '#{opt['name']}' in '#{cmd['name']}' should start with --"
        end
      end
    end
  end

  describe "excludes Thor help commands" do
    it "does not include any help entries" do
      help_cmds = catalog["commands"].select { |c| c["name"].end_with?(" help") }
      expect(help_cmds).to be_empty
    end
  end
end
