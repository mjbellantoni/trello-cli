# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::CardRef do
  describe ".parse" do
    it "parses Trello URL" do
      ref = described_class.parse("https://trello.com/c/abc123/card-name")
      expect(ref.short_link).to eq("abc123")
      expect(ref.card_number).to be_nil
    end

    it "parses card number with hash" do
      ref = described_class.parse("#42")
      expect(ref.card_number).to eq(42)
      expect(ref.short_link).to be_nil
    end

    it "parses card number without hash" do
      ref = described_class.parse("42")
      expect(ref.card_number).to eq(42)
      expect(ref.short_link).to be_nil
    end

    it "treats unknown format as short link" do
      ref = described_class.parse("xyz789")
      expect(ref.short_link).to eq("xyz789")
      expect(ref.card_number).to be_nil
    end

    it "raises error for empty input" do
      expect { described_class.parse("") }.to raise_error(ArgumentError, /empty/)
    end
  end

  describe "#matches?" do
    it "matches a card whose idShort equals a numeric ref" do
      ref = described_class.parse("#42")
      expect(ref.matches?({ "id" => "c1", "idShort" => 42, "shortLink" => "abc123" })).to be(true)
    end

    it "does not match a card with a different idShort" do
      ref = described_class.parse("#42")
      expect(ref.matches?({ "id" => "c1", "idShort" => 43, "shortLink" => "abc123" })).to be(false)
    end

    it "matches a card whose shortLink equals a ref parsed from a URL" do
      ref = described_class.parse("https://trello.com/c/abc123/card-name")
      expect(ref.matches?({ "id" => "c1", "idShort" => 42, "shortLink" => "abc123" })).to be(true)
    end

    it "matches a card whose id equals a bare ref" do
      ref = described_class.parse("61b7c9e4a1d2f3b8c7e60142")
      expect(ref.matches?({ "id" => "61b7c9e4a1d2f3b8c7e60142", "idShort" => 42,
                            "shortLink" => "abc123" })).to be(true)
    end

    it "does not match a card with a different short link" do
      ref = described_class.parse("abc123")
      expect(ref.matches?({ "id" => "c1", "idShort" => 42, "shortLink" => "zzz999" })).to be(false)
    end
  end
end
