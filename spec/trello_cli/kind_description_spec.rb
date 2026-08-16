# frozen_string_literal: true

require "spec_helper"

RSpec.describe TrelloCli::KindDescription do
  describe ".split_lines" do
    it "returns a single-element array for a plain string" do
      expect(described_class.split_lines("Open Reports")).to eq(["Open Reports"])
    end

    it "splits array elements" do
      expect(described_class.split_lines(["One", "Two"])).to eq(%w[One Two])
    end

    it "splits embedded newlines inside a single element" do
      expect(described_class.split_lines(["One\nTwo"])).to eq(%w[One Two])
    end

    it "strips caller-supplied ordered list markers" do
      expect(described_class.split_lines(["1. One", "2. Two"])).to eq(%w[One Two])
    end

    it "strips caller-supplied bullet markers" do
      expect(described_class.split_lines(["- One", "* Two"])).to eq(%w[One Two])
    end

    it "drops blank entries" do
      expect(described_class.split_lines(["One", "", "   ", "Two"])).to eq(%w[One Two])
    end
  end

  describe ".build" do
    it "numbers a bug's steps" do
      text = described_class.build(:bug, steps: ["Open Reports", "Click Export"],
                                         expected: "CSV downloads.", actual: "It hangs.")
      expect(text).to include("## Steps to Recreate\n1. Open Reports\n2. Click Export")
    end

    it "renders text fields under their heading" do
      text = described_class.build(:bug, steps: ["Open"], expected: "CSV downloads.", actual: "It hangs.")
      expect(text).to include("## Expected Behavior\nCSV downloads.")
      expect(text).to include("## Actual Behavior\nIt hangs.")
    end

    it "renders done-when as plain lines with no markers" do
      text = described_class.build(:feature, what: "Filter", why: "Speed",
                                             done_when: ["Given a queue", "When I filter", "Then it narrows"])
      expect(text).to include("## Done when\nGiven a queue\nWhen I filter\nThen it narrows")
    end

    it "omits a section entirely when its value is absent" do
      text = described_class.build(:bug, steps: ["Open"], expected: "CSV.", actual: "Hangs.")
      expect(text).not_to include("Notes")
    end

    it "includes notes when supplied" do
      text = described_class.build(:bug, steps: ["Open"], expected: "CSV.", actual: "Hangs.",
                                         notes: "https://example.com/incident/1")
      expect(text).to include("## Notes\nhttps://example.com/incident/1")
    end

    it "orders sections as the registry declares them" do
      text = described_class.build(:chore, what: "Drop table", why_now: "Blocks migration",
                                           done_when: ["Table gone"], notes: "PR 12")
      expect(text.scan(/^## (.+)$/).flatten).to eq(["What", "Why now", "Done when", "Notes"])
    end

    it "renders an array in a text field as lines, not as an inspected array" do
      text = described_class.build(:bug, steps: ["Open"], expected: %w[First Second], actual: "Hangs.")
      expect(text).to include("## Expected Behavior\nFirst\nSecond")
    end
  end

  describe "the counting invariant" do
    it "counts the whole description as the sum of its sections" do
      values = { steps: ["Open Reports", "Click Export"], expected: "CSV downloads.",
                 actual: "Spinner hangs.", notes: "https://example.com/x" }
      whole = TrelloCli::WordCount.count(described_class.build(:bug, values))
      parts = described_class.sections(:bug, values).sum { |s| TrelloCli::WordCount.count(s[:text]) }
      expect(whole).to eq(parts)
    end
  end
end
