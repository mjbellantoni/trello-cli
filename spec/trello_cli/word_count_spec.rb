# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::WordCount do
  it "returns zero for nil" do
    expect(described_class.count(nil)).to eq(0)
  end

  it "returns zero for an empty string" do
    expect(described_class.count("")).to eq(0)
  end

  it "counts whitespace-delimited tokens" do
    expect(described_class.count("one two three")).to eq(3)
  end

  it "collapses runs of whitespace" do
    expect(described_class.count("one   two\n\nthree")).to eq(3)
  end

  it "counts heading text but not the heading marker" do
    expect(described_class.count("## Steps to Recreate")).to eq(3)
  end

  it "does not count bold markers" do
    expect(described_class.count("**Expected Behavior**")).to eq(2)
  end

  it "does not count ordered list markers" do
    expect(described_class.count("1. Open Reports\n2. Click Export")).to eq(4)
  end

  it "does not count bullet markers" do
    expect(described_class.count("- Open Reports\n* Click Export")).to eq(4)
  end

  it "does not count fence delimiters but does count fenced content" do
    expect(described_class.count("```\nboom failed here\n```")).to eq(3)
  end

  it "counts a URL as one token" do
    expect(described_class.count("see https://trello.com/c/abc123 now")).to eq(3)
  end

  it "counts an assembled bug description" do
    description = <<~MD
      ## Steps to Recreate
      1. Open Reports
      2. Click Export

      ## Expected Behavior
      CSV downloads.

      ## Actual Behavior
      Spinner hangs.
    MD
    # headings "Steps to Recreate" 3 + "Expected Behavior" 2 + "Actual Behavior" 2 = 7
    # body "Open Reports" 2 + "Click Export" 2 + "CSV downloads." 2 + "Spinner hangs." 2 = 8
    expect(described_class.count(description)).to eq(15)
  end
end
