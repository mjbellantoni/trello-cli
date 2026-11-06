# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::CardJson do
  let(:card) do
    {
      "idShort" => 42, "name" => "Fix login", "desc" => "Steps to reproduce",
      "shortUrl" => "https://trello.com/c/abc123",
      "due" => "2026-11-10T17:00:00.000Z", "dueComplete" => false,
      "list" => { "id" => "l1", "name" => "Doing" },
      "labels" => [{ "name" => "Bug", "color" => "red" }],
      "members" => [{ "fullName" => "Matthew B", "username" => "mjb" },
                    { "fullName" => "", "username" => "bot" }],
      "checklists" => [{ "name" => "Steps", "checkItems" => [
        { "name" => "second", "state" => "incomplete", "pos" => 200 },
        { "name" => "first", "state" => "complete", "pos" => 100 }
      ] }],
      "attachments" => [{ "name" => "log.txt", "url" => "https://example.com/log.txt", "bytes" => 9 }],
      "idList" => "l1", "pos" => 16_384
    }
  end

  it "keeps only the fields card show prints, under stable names" do
    expect(described_class.from(card)).to eq(
      "number" => 42,
      "name" => "Fix login",
      "list" => "Doing",
      "url" => "https://trello.com/c/abc123",
      "due" => "2026-11-10T17:00:00.000Z",
      "due_complete" => false,
      "labels" => ["Bug"],
      "members" => ["Matthew B", "bot"],
      "description" => "Steps to reproduce",
      "checklists" => [{ "name" => "Steps", "items" => [
        { "name" => "first", "complete" => true },
        { "name" => "second", "complete" => false }
      ] }],
      "attachments" => [{ "name" => "log.txt", "url" => "https://example.com/log.txt" }]
    )
  end

  # A script should be able to read every key on every card without guarding
  # against it being missing.
  it "gives every key a value when the card has none of the optional parts" do
    bare = { "idShort" => 1, "name" => "Bare", "shortUrl" => "u", "desc" => "" }

    expect(described_class.from(bare).keys).to eq(%w[number name list url due due_complete labels members
                                                      description checklists attachments])
    expect(described_class.from(bare)).to include(
      "list" => nil, "due" => nil, "due_complete" => false, "labels" => [],
      "members" => [], "description" => "", "checklists" => [], "attachments" => []
    )
  end
end
