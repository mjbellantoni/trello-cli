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

    it "advertises the same position grammar for card new and card move" do
      position_for = lambda do |name|
        catalog["commands"].find { |c| c["name"] == name }["options"].find { |o| o["name"] == "--position" }
      end

      expect(position_for.call("card new")["enum"]).to be_nil
      expect(position_for.call("card new")["summary"]).to eq(position_for.call("card move")["summary"])
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

    it "includes card add-label" do
      cmd = catalog["commands"].find { |c| c["name"] == "card add-label" }
      expect(cmd).not_to be_nil
      expect(cmd["args"].map { |a| a["name"] }).to eq(%w[REF LABEL])
    end

    it "includes card remove-label" do
      cmd = catalog["commands"].find { |c| c["name"] == "card remove-label" }
      expect(cmd).not_to be_nil
      expect(cmd["args"].map { |a| a["name"] }).to eq(%w[REF LABEL])
    end

    it "includes list archive" do
      cmd = catalog["commands"].find { |c| c["name"] == "list archive" }
      expect(cmd).not_to be_nil
    end

    it "includes list cards with format option" do
      cmd = catalog["commands"].find { |c| c["name"] == "list cards" }
      expect(cmd).not_to be_nil
      format_opt = cmd["options"].find { |o| o["name"] == "--format" }
      expect(format_opt).not_to be_nil
      expect(format_opt["type"]).to eq("string")
      expect(format_opt["enum"]).to eq(%w[id id-name name])
    end

    it "includes list cards with label filter options" do
      cmd = catalog["commands"].find { |c| c["name"] == "list cards" }
      with_opt = cmd["options"].find { |o| o["name"] == "--with-label" }
      without_opt = cmd["options"].find { |o| o["name"] == "--without-label" }
      expect(with_opt).not_to be_nil
      expect(with_opt["type"]).to eq("string")
      expect(without_opt).not_to be_nil
      expect(without_opt["type"]).to eq("string")
    end

    it "includes label new with a required color enum" do
      cmd = catalog["commands"].find { |c| c["name"] == "label new" }
      expect(cmd).not_to be_nil
      expect(cmd["args"].map { |a| a["name"] }).to eq(["NAME"])
      color = cmd["options"].find { |o| o["name"] == "--color" }
      expect(color["required"]).to be(true)
      expect(color["enum"]).to include("red", "blue", "sky")
    end

    it "includes the other label commands" do
      names = catalog["commands"].map { |c| c["name"] }
      expect(names).to include("label list", "label rename", "label delete")
    end

    it "offers no force flag on label delete" do
      cmd = catalog["commands"].find { |c| c["name"] == "label delete" }
      expect(cmd["options"].map { |o| o["name"] }).not_to include("--force")
    end

    it "advertises the kind commands with their required fields" do
      cmd = catalog["commands"].find { |c| c["name"] == "bug new" }
      expect(cmd).not_to be_nil
      expect(cmd["args"].map { |a| a["name"] }).to eq(["TITLE"])

      required = cmd["options"].select { |o| o["required"] }.map { |o| o["name"] }
      expect(required).to contain_exactly("--steps", "--expected", "--actual")
    end

    it "advertises done-when on feature and chore" do
      %w[feature chore].each do |kind|
        cmd = catalog["commands"].find { |c| c["name"] == "#{kind} new" }
        expect(cmd["options"].map { |o| o["name"] }).to include("--done-when")
      end
    end

    it "offers no force flag on any kind command" do
      TrelloCli::Kinds.names.each do |kind|
        cmd = catalog["commands"].find { |c| c["name"] == "#{kind} new" }
        expect(cmd["options"].map { |o| o["name"] }).not_to include("--force")
      end
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
