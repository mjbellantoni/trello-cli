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
end
