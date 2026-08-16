# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::Kinds do
  it "knows the three kinds" do
    expect(described_class.names).to eq(%i[bug feature chore])
  end

  it "raises for an unknown kind" do
    expect { described_class.fetch(:epic) }.to raise_error(TrelloCli::Error, /epic/)
  end

  it "orders bug fields steps, expected, actual, notes" do
    flags = described_class.fetch(:bug)[:fields].map { |f| f[:flag] }
    expect(flags).to eq(%i[steps expected actual notes])
  end

  it "uses the existing board headings for a bug" do
    headings = described_class.fetch(:bug)[:fields].map { |f| f[:heading] }
    expect(headings).to eq(["Steps to Recreate", "Expected Behavior", "Actual Behavior", "Notes"])
  end

  it "uses the existing board headings for a feature" do
    headings = described_class.fetch(:feature)[:fields].map { |f| f[:heading] }
    expect(headings).to eq(["What", "Why", "Done when", "Notes"])
  end

  it "uses the existing board headings for a chore" do
    headings = described_class.fetch(:chore)[:fields].map { |f| f[:heading] }
    expect(headings).to eq(["What", "Why now", "Done when", "Notes"])
  end

  it "marks notes optional and every other field required" do
    described_class.names.each do |kind|
      described_class.fetch(kind)[:fields].each do |field|
        expect(field[:required]).to eq(field[:flag] != :notes)
      end
    end
  end

  it "numbers bug steps and renders done-when as plain lines" do
    expect(described_class.fetch(:bug)[:fields].first[:format]).to eq(:numbered)
    done_when = described_class.fetch(:feature)[:fields].find { |f| f[:flag] == :done_when }
    expect(done_when[:format]).to eq(:lines)
  end

  it "requires gherkin only for a feature" do
    expect(described_class.fetch(:feature)[:gherkin]).to be(true)
    expect(described_class.fetch(:bug)[:gherkin]).to be_falsey
    expect(described_class.fetch(:chore)[:gherkin]).to be_falsey
  end
end
