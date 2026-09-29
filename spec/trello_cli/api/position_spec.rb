# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Api::Position do
  describe ".parse" do
    it "passes a keyword through unchanged" do
      expect(described_class.parse("top")).to eq("top")
    end

    it "converts a numeric string to a float" do
      expect(described_class.parse("2")).to eq(2.0)
    end

    # A computed midpoint arrives as a number, not a string.
    it "accepts a number and returns it as a float" do
      expect(described_class.parse(1.5)).to eq(1.5)
    end

    it "raises for input that is neither a keyword nor a number" do
      expect { described_class.parse("abc") }.to raise_error(TrelloCli::Error, /position/i)
    end
  end
end
